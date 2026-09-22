#!/usr/bin/env node
import { lstat, readFile, readdir } from 'node:fs/promises';
import { dirname, isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const fail = (message) => { console.error(`[governance] ${message}`); process.exitCode = 1; };
const expectedValidatorRevision = 'bd503465dab8c5148fee722b443ed04ff126c9bf';
const sha40 = /^[0-9a-f]{40}$/;

function within(base, target) {
  const r = relative(base, target);
  return r === '' || (!r.startsWith(`..${sep}`) && r !== '..' && !isAbsolute(r));
}

function repoPath(value, label) {
  if (typeof value !== 'string' || !value || value.includes('\0') || isAbsolute(value)) throw new Error(`${label} must be repository-relative`);
  const absolute = resolve(root, value);
  if (!within(root, absolute)) throw new Error(`${label} escapes repository root`);
  return absolute;
}

async function realFile(value, label) {
  const absolute = repoPath(value, label);
  const st = await lstat(absolute);
  if (st.isSymbolicLink() || !st.isFile()) throw new Error(`${label} must be a real file: ${value}`);
  return absolute;
}

async function realDirectory(value, label) {
  const absolute = repoPath(value, label);
  const st = await lstat(absolute);
  if (st.isSymbolicLink() || !st.isDirectory()) throw new Error(`${label} must be a real directory: ${value}`);
  return absolute;
}

function parseSupportMatrix(source) {
  const result = { apm: {}, statusValues: [], languages: new Map() };
  let section = '';
  for (const raw of source.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const header = line.match(/^\[([^\]]+)\]$/);
    if (header) { section = header[1]; continue; }
    const kv = line.match(/^([A-Za-z0-9_]+)\s*=\s*(.+)$/);
    if (!kv) continue;
    const [, key, rawValue] = kv;
    const stringValue = rawValue.match(/^"(.*)"$/)?.[1];
    const intValue = /^\d+$/.test(rawValue) ? Number(rawValue) : null;
    const arrayValue = rawValue.startsWith('[') ? [...rawValue.matchAll(/"([^"]*)"/g)].map((m) => m[1]) : null;
    if (section === 'apm') {
      if (key === 'status_values') result.statusValues = arrayValue ?? [];
      else result.apm[key] = stringValue ?? intValue ?? rawValue;
      continue;
    }
    const language = section.match(/^languages\.([A-Za-z0-9_-]+)$/)?.[1];
    if (language) {
      if (!result.languages.has(language)) result.languages.set(language, {});
      result.languages.get(language)[key] = stringValue ?? intValue ?? rawValue;
    }
  }
  return result;
}

function zpkgClientDirs(source) {
  const dirs = new Map();
  let target = null;
  for (const raw of source.split(/\r?\n/)) {
    const line = raw.trim();
    const section = line.match(/^\[targets\.([A-Za-z0-9_-]+)\]$/);
    if (section) { target = section[1]; continue; }
    if (/^\[/.test(line)) { target = null; continue; }
    if (!target) continue;
    const dir = line.match(/^dir\s*=\s*"([^"]+)"\s*$/)?.[1];
    if (dir?.startsWith('clients/')) {
      if (dirs.has(target)) throw new Error(`duplicate Zed target: ${target}`);
      dirs.set(target, dir);
    }
  }
  return dirs;
}

try {
  const clientsRoot = await realDirectory('clients', 'clients root');
  const actualLanguages = [];
  for (const entry of (await readdir(clientsRoot, { withFileTypes: true })).sort((a,b) => a.name.localeCompare(b.name))) {
    if (entry.name === 'support-matrix.toml') continue;
    if (entry.isSymbolicLink() || !entry.isDirectory()) throw new Error(`clients/ may contain only language directories plus support-matrix.toml: ${entry.name}`);
    actualLanguages.push(entry.name);
  }

  const matrix = parseSupportMatrix(await readFile(await realFile('clients/support-matrix.toml', 'support matrix'), 'utf8'));
  const declaredLanguages = [...matrix.languages.keys()].sort();
  const missingInMatrix = actualLanguages.filter((x) => !matrix.languages.has(x));
  const staleInMatrix = declaredLanguages.filter((x) => !actualLanguages.includes(x));
  if (missingInMatrix.length || staleInMatrix.length) throw new Error(`support-matrix drift; missing=${missingInMatrix.join(',')} stale=${staleInMatrix.join(',')}`);

  if (!Array.isArray(matrix.statusValues) || matrix.statusValues.length === 0) throw new Error('apm.status_values must be non-empty');
  const allowedStatus = new Set(matrix.statusValues);
  if (allowedStatus.size !== matrix.statusValues.length) throw new Error('apm.status_values contains duplicates');
  for (const [language, config] of matrix.languages) {
    if (!Number.isInteger(config.tier) || config.tier < 1 || config.tier > 3) throw new Error(`invalid tier for ${language}`);
    if (typeof config.apm !== 'string' || !allowedStatus.has(config.apm)) throw new Error(`invalid APM state for ${language}: ${config.apm}`);
  }

  const zpkg = zpkgClientDirs(await readFile(await realFile('.zpkg.toml', 'Zed manifest'), 'utf8'));
  const zpkgDirs = [...zpkg.values()].sort();
  const expectedDirs = actualLanguages.map((language) => `clients/${language}`).sort();
  const missingZed = expectedDirs.filter((dir) => !zpkgDirs.includes(dir));
  const staleZed = zpkgDirs.filter((dir) => !expectedDirs.includes(dir));
  if (missingZed.length || staleZed.length) throw new Error(`Zed client target drift; missing=${missingZed.join(',')} stale=${staleZed.join(',')}`);
  if (new Set(zpkgDirs).size !== zpkgDirs.length) throw new Error('multiple Zed targets point at the same client directory');

  const lock = JSON.parse(await readFile(await realFile('contracts/ores-apm.lock.json', 'APM authority lock'), 'utf8'));
  if (lock.schema !== 'ores-otel.apm-client-contract-lock/v1') throw new Error('invalid APM authority lock schema');
  if (lock.repository !== matrix.apm.contract_repository) throw new Error('APM authority repository drift between lock and support matrix');
  if (!sha40.test(lock.revision) || lock.revision !== matrix.apm.contract_revision) throw new Error('APM authority revision drift between lock and support matrix');
  if (lock.typespec !== matrix.apm.typespec) throw new Error('APM TypeSpec path drift between lock and support matrix');
  if (lock.jsonSchema !== matrix.apm.json_schema) throw new Error('APM JSON Schema path drift between lock and support matrix');
  if (lock.fixture !== matrix.apm.fixture) throw new Error('APM fixture path drift between lock and support matrix');
  if (matrix.apm.precedence !== 'none' || matrix.apm.generated_schema_role !== 'comparison-evidence-only') throw new Error('unsafe APM peer-authority policy');

  const admission = JSON.parse(await readFile(await realFile('contract-admission/contract-ir-consumer.json', 'contract admission manifest'), 'utf8'));
  if (admission.schema !== 'ores.contract-ir-consumer/v1' || admission.repository !== 'ores-otel/ores-otel-clients' || admission.repositoryRole !== 'clients') throw new Error('invalid contract admission identity');
  if (admission.canonicalAuthorityRepository !== lock.repository) throw new Error('contract admission authority repository drift');
  if (admission.validator?.repository !== 'ORESoftware/typespec-json-schema-validator') throw new Error('unexpected validator repository');
  if (admission.validator?.actionCommit !== expectedValidatorRevision) throw new Error(`validator pin drift; expected ${expectedValidatorRevision}`);
  if (admission.authorityModel?.precedence !== 'none' || admission.admission?.allowFallbackAuthority !== false) throw new Error('unsafe contract-admission authority policy');
  for (const key of ['requirePassedReceipt','requireAdmissibleContractIr','requireZeroUnexplainedFindings','rejectEditableAuthority']) if (admission.admission?.[key] !== true) throw new Error(`contract admission must fail closed: ${key}`);

  const conformance = JSON.parse(await readFile(await realFile('conformance/manifest.v1.json', 'conformance manifest'), 'utf8'));
  if (conformance.repository !== 'ores-otel/ores-otel-clients') throw new Error('conformance repository identity drift');
  for (const participant of conformance.requiredParticipants ?? []) {
    if (!participant || typeof participant.id !== 'string' || !matrix.languages.has(participant.id)) throw new Error(`unknown required client conformance participant: ${participant?.id}`);
  }

  console.log(JSON.stringify({
    schema: 'ores.governance.client-matrix-check/v1',
    repository: 'ores-otel/ores-otel-clients',
    client_count: actualLanguages.length,
    clients: actualLanguages,
    zpkg_targets: [...zpkg.keys()].sort(),
    apm_authority: { repository: lock.repository, revision: lock.revision },
    validator_revision: admission.validator.actionCommit
  }, null, 2));
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
