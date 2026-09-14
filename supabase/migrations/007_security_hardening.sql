-- Security hardening surfaced by the database linter.

-- 1) Pin search_path on trigger functions (function_search_path_mutable).
alter function public.protect_accountability_link() set search_path = public;
alter function public.protect_users_server_fields() set search_path = public;
alter function public.protect_blocked_config_server_fields() set search_path = public;
alter function public.protect_fine_proof_update() set search_path = public;
alter function public.protect_users_report_fields() set search_path = public;

-- 2) These SECURITY DEFINER helpers are used internally by triggers/policies
-- and must NOT be callable as PostgREST RPCs by anon/authenticated.
revoke all on function public.handle_new_auth_user() from anon, authenticated;
revoke all on function public.set_updated_at() from anon, authenticated;
-- has_admin_role is referenced inside RLS policies (runs as the querying role
-- for `authenticated`), so only anon's direct RPC access is revoked.
revoke all on function public.has_admin_role(uuid) from anon;
revoke all on function public.purge_expired_email_otps() from anon, authenticated;
