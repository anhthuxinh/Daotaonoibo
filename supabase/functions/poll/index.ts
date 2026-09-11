import { createClient } from 'npm:@supabase/supabase-js@2'

const choices = ['topic', 'learner', 'content', 'interaction', 'delivery'] as const
type Choice = typeof choices[number]

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  Response.json(body, {
    status,
    headers: {
      'Cache-Control': 'no-store',
      ...corsHeaders,
    },
  })

const validId = (value: unknown, max: number) =>
  typeof value === 'string' && value.length >= 6 && value.length <= max && /^[a-zA-Z0-9_-]+$/.test(value)

async function readResults(admin: any, sessionId: string) {
  const { data, error } = await admin.rpc('get_poll_results', { p_session_id: sessionId })
  if (error) throw error

  const counts: Record<Choice, number> = {
    topic: 0,
    learner: 0,
    content: 0,
    interaction: 0,
    delivery: 0,
  }
  for (const row of data ?? []) {
    if (choices.includes(row.choice)) counts[row.choice as Choice] = Number(row.vote_count) || 0
  }
  return { counts, total: Object.values(counts).reduce((sum, count) => sum + count, 0) }
}

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false, autoRefreshToken: false } },
)

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders })
    }

    try {
      const url = new URL(req.url)

      if (req.method === 'GET') {
        const sessionId = url.searchParams.get('session')
        if (!validId(sessionId, 80)) return json({ error: 'Phiên bình chọn không hợp lệ.' }, 400)
        return json(await readResults(supabaseAdmin, sessionId!))
      }

      if (req.method === 'POST') {
        const body = await req.json().catch(() => null)
        if (!body || !validId(body.session_id, 80) || !validId(body.voter_id, 120) || !choices.includes(body.choice)) {
          return json({ error: 'Dữ liệu bình chọn không hợp lệ.' }, 400)
        }

        const { data: accepted, error } = await supabaseAdmin.rpc('submit_poll_vote', {
          p_session_id: body.session_id,
          p_voter_id: body.voter_id,
          p_choice: body.choice,
        })
        if (error) throw error
        return json({
          ok: true,
          accepted: Boolean(accepted),
          ...(await readResults(supabaseAdmin, body.session_id)),
        })
      }

      return json({ error: 'Phương thức không được hỗ trợ.' }, 405)
    } catch (error) {
      console.error(error)
      return json({ error: 'Dịch vụ bình chọn đang bận. Vui lòng thử lại.' }, 500)
    }
})

