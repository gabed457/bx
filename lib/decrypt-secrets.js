#!/usr/bin/env node
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const DEBUG = process.env.BX_DEBUG === '1';

function debug(msg) {
  if (DEBUG) process.stderr.write(`[debug] ${msg}\n`);
}

function die(msg) {
  process.stderr.write(`error: ${msg}\n`);
  process.exit(1);
}

function parseArgs(args) {
  const result = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--collection-path' && i + 1 < args.length) {
      result.collectionPath = args[++i];
    } else if (args[i] === '--env' && i + 1 < args.length) {
      result.env = args[++i];
    }
  }
  return result;
}

function posixify(p) {
  return p.replace(/\\/g, '/');
}

function getSecretsPath() {
  if (process.env.BX_SECRETS_FILE) {
    return process.env.BX_SECRETS_FILE;
  }
  const home = process.env.HOME || process.env.USERPROFILE;
  if (process.platform === 'darwin') {
    return path.join(home, 'Library', 'Application Support', 'bruno', 'secrets.json');
  }
  const configHome = process.env.XDG_CONFIG_HOME || path.join(home, '.config');
  return path.join(configHome, 'bruno', 'secrets.json');
}

let _keychainPassword = null;

function getKeychainPassword() {
  if (_keychainPassword !== null) return _keychainPassword;

  if (process.env.BX_BRUNO_SAFE_STORAGE_PASSWORD) {
    _keychainPassword = process.env.BX_BRUNO_SAFE_STORAGE_PASSWORD;
    return _keychainPassword;
  }

  try {
    _keychainPassword = execSync(
      'security find-generic-password -s "bruno Safe Storage" -a "bruno Key" -w',
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();
    return _keychainPassword;
  } catch (e) {
    debug(`Failed to get keychain password: ${e.message}`);
    return null;
  }
}

function decryptSafeStorage(hexData) {
  const password = getKeychainPassword();
  if (!password) {
    debug('No keychain password available, skipping $00: secret');
    return null;
  }

  const encryptedBytes = Buffer.from(hexData, 'hex');
  if (encryptedBytes.length < 3) {
    debug('Encrypted data too short');
    return null;
  }
  const data = encryptedBytes.slice(3);

  const key = crypto.pbkdf2Sync(password, 'saltysalt', 1003, 16, 'sha1');
  const iv = Buffer.alloc(16, 0x20);

  try {
    const decipher = crypto.createDecipheriv('aes-128-cbc', key, iv);
    let decrypted = decipher.update(data);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return decrypted.toString('utf8');
  } catch (e) {
    debug(`SafeStorage decryption failed: ${e.message}`);
    return null;
  }
}

function getMachineId() {
  if (process.env.BX_MACHINE_ID) {
    return process.env.BX_MACHINE_ID;
  }

  const candidates = [
    '/etc/machine-id',
    '/var/lib/dbus/machine-id',
  ];

  for (const p of candidates) {
    try {
      return fs.readFileSync(p, 'utf8').trim();
    } catch (e) {
      // continue
    }
  }

  if (process.platform === 'darwin') {
    try {
      const output = execSync(
        "ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/{print $3}'",
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
      ).trim().replace(/"/g, '');
      if (output) return output;
    } catch (e) {
      // continue
    }
  }

  return null;
}

function decryptAes256(hexData) {
  const machineId = getMachineId();
  if (!machineId) {
    debug('No machine ID available, skipping $01: secret');
    return null;
  }

  const encryptedData = Buffer.from(hexData, 'hex');
  const iv = Buffer.alloc(16, 0);

  const key = crypto.createHash('sha256').update(machineId).digest();

  try {
    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
    let decrypted = decipher.update(encryptedData);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return decrypted.toString('utf8');
  } catch (e) {
    debug(`AES-256-CBC (SHA-256) decryption failed: ${e.message}, trying MD5 fallback`);

    try {
      const md5Key = crypto.createHash('md5').update(machineId).digest();
      const fallbackKey = Buffer.concat([md5Key, md5Key]);
      const decipher2 = crypto.createDecipheriv('aes-256-cbc', fallbackKey, iv);
      let decrypted2 = decipher2.update(encryptedData);
      decrypted2 = Buffer.concat([decrypted2, decipher2.final()]);
      return decrypted2.toString('utf8');
    } catch (e2) {
      debug(`AES-256-CBC (MD5 fallback) also failed: ${e2.message}`);
      return null;
    }
  }
}

function decryptSecret(value) {
  if (!value || typeof value !== 'string') return null;

  if (value.startsWith('$00:')) {
    return decryptSafeStorage(value.slice(4));
  } else if (value.startsWith('$01:')) {
    return decryptAes256(value.slice(4));
  }

  debug(`Unknown secret prefix: ${value.substring(0, 4)}...`);
  return null;
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.collectionPath || !args.env) {
    die('Usage: decrypt-secrets.js --collection-path <path> --env <name>');
  }

  const secretsPath = getSecretsPath();
  debug(`secrets.json path: ${secretsPath}`);

  if (!fs.existsSync(secretsPath)) {
    debug('secrets.json not found');
    process.exit(0);
  }

  let secretsData;
  try {
    secretsData = JSON.parse(fs.readFileSync(secretsPath, 'utf8'));
  } catch (e) {
    die(`Failed to parse secrets.json: ${e.message}`);
  }

  if (!secretsData.collections || !Array.isArray(secretsData.collections)) {
    debug('No collections in secrets.json');
    process.exit(0);
  }

  const normalizedPath = posixify(args.collectionPath);
  debug(`Looking for collection: ${normalizedPath}`);

  const collection = secretsData.collections.find(
    c => posixify(c.path) === normalizedPath
  );

  if (!collection) {
    debug('No matching collection found');
    process.exit(0);
  }

  if (!collection.environments || !Array.isArray(collection.environments)) {
    debug('No environments in collection');
    process.exit(0);
  }

  const env = collection.environments.find(e => e.name === args.env);

  if (!env) {
    debug(`No matching environment '${args.env}' found`);
    process.exit(0);
  }

  if (!env.secrets || !Array.isArray(env.secrets)) {
    debug('No secrets in environment');
    process.exit(0);
  }

  for (const secret of env.secrets) {
    if (!secret.name || !secret.value) continue;

    const decrypted = decryptSecret(secret.value);
    if (decrypted !== null) {
      process.stdout.write(`${secret.name}=${decrypted}\n`);
    } else {
      debug(`Failed to decrypt secret: ${secret.name}`);
    }
  }
}

main();
