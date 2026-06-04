#!/usr/bin/env node
/**
 * Starts PostgreSQL for local development.
 * Prefers Docker Compose; falls back to embedded-postgres when Docker is unavailable.
 */
import { createConnection } from 'node:net';
import { execSync, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dataDir = join(root, '.data', 'postgres');
const markerFile = join(dataDir, '.schema-applied');
const dbName = process.env.DB_NAME ?? 'centerize_pms';
const dbUser = process.env.DB_USER ?? 'postgres';
const dbPassword = process.env.DB_PASSWORD ?? 'postgres';
const dbPort = Number(process.env.DB_PORT ?? 5432);

function isPortOpen(port) {
  return new Promise((resolve) => {
    const socket = createConnection({ port, host: '127.0.0.1' });
    socket.once('connect', () => {
      socket.end();
      resolve(true);
    });
    socket.once('error', () => resolve(false));
  });
}

function hasDocker() {
  try {
    execSync('docker compose version', { stdio: 'ignore' });
    return true;
  } catch {
    const dockerDesktop = '/Applications/Docker.app/Contents/Resources/bin/docker';
    if (existsSync(dockerDesktop)) {
      process.env.PATH = `${dirname(dockerDesktop)}:${process.env.PATH}`;
      try {
        execSync('docker compose version', { stdio: 'ignore' });
        return true;
      } catch {
        return false;
      }
    }
    return false;
  }
}

function waitForDockerHealth(maxAttempts = 30) {
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const result = spawnSync(
      'docker',
      ['compose', 'ps', '--format', '{{.Health}}'],
      { cwd: root, encoding: 'utf8' },
    );
    if (result.stdout?.includes('healthy')) {
      return;
    }
    execSync('sleep 2');
  }
  throw new Error('Postgres container did not become healthy in time');
}

async function applySqlFiles(pg) {
  if (existsSync(markerFile)) {
    console.log('Embedded DB already initialized (schema + seed). Skipping SQL apply.');
    return;
  }

  try {
    await pg.createDatabase(dbName);
  } catch {
    // database may already exist on re-runs
  }
  const client = pg.getPgClient(dbName);
  await client.connect();

  const schemaSql = readFileSync(join(root, 'schema.sql'), 'utf8');
  const seedSql = readFileSync(join(root, 'seed.sql'), 'utf8');

  console.log('Applying schema.sql …');
  await client.query(schemaSql);
  console.log('Applying seed.sql …');
  await client.query(seedSql);
  await client.end();

  writeFileSync(markerFile, new Date().toISOString());
  console.log('Schema and seed applied.');
}

async function startEmbedded() {
  console.log('Docker not found — starting embedded PostgreSQL …');
  const pg = new EmbeddedPostgres({
    databaseDir: dataDir,
    user: dbUser,
    password: dbPassword,
    port: dbPort,
    persistent: true,
  });

  await pg.initialise();
  await pg.start();
  await applySqlFiles(pg);

  console.log(
    `Embedded Postgres ready on localhost:${dbPort} (database: ${dbName})`,
  );
  console.log('Press Ctrl+C to stop embedded Postgres.');

  const shutdown = async () => {
    await pg.stop();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  await new Promise(() => {});
}

async function main() {
  if (!hasDocker() && (await isPortOpen(dbPort)) && existsSync(markerFile)) {
    console.log(
      `Postgres already listening on localhost:${dbPort} (embedded data in .data/postgres).`,
    );
    return;
  }

  if (hasDocker()) {
    console.log('Starting PostgreSQL via Docker Compose …');
    const up = spawnSync('docker', ['compose', 'up', '-d'], {
      cwd: root,
      stdio: 'inherit',
    });
    if (up.status !== 0) {
      process.exit(up.status ?? 1);
    }
    waitForDockerHealth();
    console.log('Docker Postgres is up and healthy.');
    return;
  }

  await startEmbedded();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
