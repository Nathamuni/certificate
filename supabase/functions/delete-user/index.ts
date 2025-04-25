import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

console.log('Delete User function started');

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in Edge Function secrets
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error('Missing Supabase URL or Service Role Key environment variables.');
    }

    // Create Supabase Admin Client
    // Note: service_role key bypasses RLS. Use with caution.
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Get userId from request body
    const { userId } = await req.json();

    if (!userId) {
      return new Response(JSON.stringify({ error: 'Missing userId in request body' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    console.log(`Attempting to delete user: ${userId}`);

    // Delete the user using the Admin API
    const { data, error } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (error) {
      console.error('Error deleting user:', error);
      // Provide a more specific error message if possible
      let errorMessage = error.message;
      let status = 500;
      if (error.message.includes('User not found')) {
          errorMessage = 'User not found.';
          status = 404; // Not Found is more appropriate
      } else if (error.message.includes('Database error deleting user')) {
          errorMessage = 'Database error during user deletion.';
          status = 500;
      }
      // Add more specific error handling if needed based on observed errors

      return new Response(JSON.stringify({ error: `Failed to delete user: ${errorMessage}` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: status, // Use appropriate HTTP status code
      });
    }

    console.log(`Successfully deleted user: ${userId}`, data);

    // Optionally: Delete corresponding profile data if not handled by cascade
    // const { error: profileError } = await supabaseAdmin
    //   .from('profiles')
    //   .delete()
    //   .eq('id', userId);
    // if (profileError) {
    //   console.warn(`User ${userId} deleted from auth, but failed to delete profile: ${profileError.message}`);
    //   // Decide if this should be a partial success or still an error
    // }

    return new Response(JSON.stringify({ message: 'User deleted successfully' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Unhandled error:', error);
    return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/*
To deploy:
1. Ensure Supabase CLI is installed and you are logged in (`supabase login`).
2. Link your project: `supabase link --project-ref your-project-ref`
3. Set secrets:
   `supabase secrets set SUPABASE_URL=your-supabase-url`
   `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key`
4. Deploy the function: `supabase functions deploy delete-user --no-verify-jwt`
   (Use --no-verify-jwt because we are using the service_role key for admin access)
*/
