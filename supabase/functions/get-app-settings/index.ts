import { adminClient, FunctionError, invoke, requireUser } from "../_shared/common.ts";

Deno.serve((req) => invoke("get-app-settings", req, async (request) => {
  await requireUser(request);

  const { data, error } = await adminClient
    .from("app_settings")
    .select("*")
    .eq("id", 1)
    .single();

  if (error) throw new FunctionError(500, "Could not retrieve app settings.");

  return data;
}));
