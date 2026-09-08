/* NovaMart Supabase configuration.
   Replace ONLY the two placeholders below with your project's public values.
   Never put a service_role key or database password in this file.
*/
window.NOVAMART_SUPABASE = {
  url: 'YOUR_SUPABASE_PROJECT_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY'
};

window.NOVAMART_SUPABASE_READY = () => {
  const c = window.NOVAMART_SUPABASE;
  return Boolean(c && c.url && c.anonKey && !c.url.includes('YOUR_') && !c.anonKey.includes('YOUR_'));
};
