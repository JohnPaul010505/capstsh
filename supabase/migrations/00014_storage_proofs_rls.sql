

drop policy if exists "proofs_insert" on storage.objects;
create policy "proofs_insert" on storage.objects for insert
  to authenticated
  with check (bucket_id = 'proofs');

drop policy if exists "proofs_select" on storage.objects;
create policy "proofs_select" on storage.objects for select
  to authenticated
  using (bucket_id = 'proofs');

drop policy if exists "proofs_update" on storage.objects;
create policy "proofs_update" on storage.objects for update
  to authenticated
  using (bucket_id = 'proofs');

drop policy if exists "proofs_delete" on storage.objects;
create policy "proofs_delete" on storage.objects for delete
  to authenticated
  using (bucket_id = 'proofs');