-- HR Employee Name Model minimal compatible upgrade v1
-- Scope: add local/latin name fields to employees only

alter table if exists employees
  add column if not exists family_name_local text,
  add column if not exists given_name_local text,
  add column if not exists full_name_local text,
  add column if not exists family_name_latin text,
  add column if not exists given_name_latin text,
  add column if not exists full_name_latin text;
