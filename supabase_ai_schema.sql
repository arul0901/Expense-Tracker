-- =====================================================================
-- PROFIN — AI FINANCIAL ASSISTANT SCHEMA & SECURE POSTGRESQL RPCs
-- HYBRID RAG (pgvector) + DETERMINISTIC FINANCIAL TOOL RPCs
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. EXTENSIONS
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;

-- ---------------------------------------------------------------------
-- 2. SEMANTIC MEMORY TABLE FOR RAG
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.financial_ai_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL DEFAULT 'summary', -- 'monthly_summary', 'trip_notes', 'spending_pattern', 'subscription', 'custom_note'
    source_id TEXT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    embedding vector(384), -- 384 dimensions matching open-source standard embeddings (gte-small / miniLM)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for user filtering + vector similarity search
CREATE INDEX IF NOT EXISTS idx_financial_ai_documents_user ON public.financial_ai_documents(user_id);

ALTER TABLE public.financial_ai_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own financial AI documents" ON public.financial_ai_documents;
CREATE POLICY "Users can read own financial AI documents"
ON public.financial_ai_documents FOR SELECT TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own financial AI documents" ON public.financial_ai_documents;
CREATE POLICY "Users can insert own financial AI documents"
ON public.financial_ai_documents FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own financial AI documents" ON public.financial_ai_documents;
CREATE POLICY "Users can update own financial AI documents"
ON public.financial_ai_documents FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own financial AI documents" ON public.financial_ai_documents;
CREATE POLICY "Users can delete own financial AI documents"
ON public.financial_ai_documents FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- 3. SEMANTIC VECTOR MATCH RPC
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.match_financial_memory(
    query_embedding vector(384),
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.3
)
RETURNS TABLE (
    id UUID,
    source_type TEXT,
    source_id TEXT,
    title TEXT,
    content TEXT,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        doc.id,
        doc.source_type,
        doc.source_id,
        doc.title,
        doc.content,
        doc.metadata,
        1 - (doc.embedding <=> query_embedding) AS similarity
    FROM public.financial_ai_documents doc
    WHERE doc.user_id = auth.uid()
      AND doc.embedding IS NOT NULL
      AND (1 - (doc.embedding <=> query_embedding)) >= similarity_threshold
    ORDER BY doc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- =====================================================================
-- 4. DETERMINISTIC SECURE FINANCIAL TOOL RPCs
-- =====================================================================

-- ---------------------------------------------------------------------
-- TOOL 1: Get Monthly Spending Summary
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_monthly_spending(p_month INT, p_year INT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
    v_total_expense_paise BIGINT := 0;
    v_total_income_paise BIGINT := 0;
    v_categories JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    v_start_date := MAKE_TIMESTAMPTZ(p_year, p_month, 1, 0, 0, 0, 'UTC');
    v_end_date := (v_start_date + INTERVAL '1 month') - INTERVAL '1 microsecond';

    -- Total Expense
    SELECT COALESCE(SUM(amount_paise), 0)
    INTO v_total_expense_paise
    FROM public.transactions
    WHERE user_id = v_user_id
      AND type = 'expense'
      AND date >= v_start_date
      AND date <= v_end_date;

    -- Total Income
    SELECT COALESCE(SUM(amount_paise), 0)
    INTO v_total_income_paise
    FROM public.transactions
    WHERE user_id = v_user_id
      AND type = 'income'
      AND date >= v_start_date
      AND date <= v_end_date;

    -- Category Breakdown
    SELECT COALESCE(jsonb_agg(cat_row), '[]'::jsonb)
    INTO v_categories
    FROM (
        SELECT 
            COALESCE(c.name, 'Uncategorized') AS category_name,
            SUM(t.amount_paise) AS total_paise,
            ROUND((SUM(t.amount_paise)::NUMERIC / 100.0), 2) AS total_rupees
        FROM public.transactions t
        LEFT JOIN public.categories c ON t.category_id = c.id
        WHERE t.user_id = v_user_id
          AND t.type = 'expense'
          AND t.date >= v_start_date
          AND t.date <= v_end_date
        GROUP BY c.name
        ORDER BY total_paise DESC
    ) cat_row;

    RETURN jsonb_build_object(
        'month', p_month,
        'year', p_year,
        'total_expense_paise', v_total_expense_paise,
        'total_expense_rupees', ROUND((v_total_expense_paise::NUMERIC / 100.0), 2),
        'total_income_paise', v_total_income_paise,
        'total_income_rupees', ROUND((v_total_income_paise::NUMERIC / 100.0), 2),
        'net_savings_rupees', ROUND(((v_total_income_paise - v_total_expense_paise)::NUMERIC / 100.0), 2),
        'category_breakdown', v_categories
    );
END;
$$;

-- ---------------------------------------------------------------------
-- TOOL 2: Get Weekly Spending
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_weekly_spending()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_start_date TIMESTAMPTZ := date_trunc('week', NOW());
    v_end_date TIMESTAMPTZ := NOW();
    v_total_expense_paise BIGINT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    SELECT COALESCE(SUM(amount_paise), 0)
    INTO v_total_expense_paise
    FROM public.transactions
    WHERE user_id = v_user_id
      AND type = 'expense'
      AND date >= v_start_date;

    RETURN jsonb_build_object(
        'week_start', v_start_date,
        'total_expense_paise', v_total_expense_paise,
        'total_expense_rupees', ROUND((v_total_expense_paise::NUMERIC / 100.0), 2)
    );
END;
$$;

-- ---------------------------------------------------------------------
-- TOOL 3: Get Category Spending Breakdown
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_category_spending(p_start_date TIMESTAMPTZ DEFAULT NULL, p_end_date TIMESTAMPTZ DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_start TIMESTAMPTZ := COALESCE(p_start_date, date_trunc('month', NOW()));
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT 
            COALESCE(c.name, 'Uncategorized') AS category,
            SUM(t.amount_paise) AS amount_paise,
            ROUND((SUM(t.amount_paise)::NUMERIC / 100.0), 2) AS amount_rupees,
            COUNT(t.id) AS transaction_count
        FROM public.transactions t
        LEFT JOIN public.categories c ON t.category_id = c.id
        WHERE t.user_id = v_user_id
          AND t.type = 'expense'
          AND t.date >= v_start
          AND t.date <= v_end
        GROUP BY c.name
        ORDER BY amount_paise DESC
    ) r;

    RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------
-- TOOL 4: Get People Who Owe Me (Net Receivables)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_people_who_owe_me()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    -- ================================================================
    -- AUTHENTICATION
    -- ================================================================

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    -- ================================================================
    -- BUILD RECEIVABLES
    -- ================================================================

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'person_name', sub.person_name,
                'person_user_id', sub.person_user_id,
                'room_name', sub.room_name,
                'net_receivable_paise', sub.net_receivable_paise,
                'net_receivable_rupees',
                    ROUND(
                        sub.net_receivable_paise::NUMERIC / 100.0,
                        2
                    )
            )
            ORDER BY sub.net_receivable_paise DESC
        ),
        '[]'::jsonb
    )
    INTO v_result
    FROM (
        SELECT
            rm.member_name AS person_name,
            rm.user_id AS person_user_id,
            r.name AS room_name,

            -- ========================================================
            -- NET RECEIVABLE
            --
            -- Positive means:
            -- The other person owes the current user.
            --
            -- Negative means:
            -- The current user owes the other person.
            -- ========================================================

            (
                -- ----------------------------------------------------
                -- 1. Expenses YOU paid where the other person owes
                --    a share.
                -- ----------------------------------------------------
                COALESCE((
                    SELECT SUM(es.amount_paise)
                    FROM public.room_expenses re
                    JOIN public.expense_splits es
                        ON es.room_expense_id = re.id
                    WHERE re.room_id = rm.room_id
                      AND re.paid_by_user_id = v_user_id
                      AND (
                          es.user_id = rm.user_id
                          OR (
                              es.member_name = rm.member_name
                              AND rm.user_id IS NULL
                          )
                      )
                ), 0)

                -

                -- ----------------------------------------------------
                -- 2. Expenses the OTHER PERSON paid where YOU owe
                --    a share.
                -- ----------------------------------------------------
                COALESCE((
                    SELECT SUM(es.amount_paise)
                    FROM public.room_expenses re
                    JOIN public.expense_splits es
                        ON es.room_expense_id = re.id
                    WHERE re.room_id = rm.room_id
                      AND (
                          re.paid_by_user_id = rm.user_id
                          OR (
                              re.paid_by_member_name = rm.member_name
                              AND rm.user_id IS NULL
                          )
                      )
                      AND es.user_id = v_user_id
                ), 0)

                +

                -- ----------------------------------------------------
                -- 3. SETTLEMENTS where the OTHER PERSON paid you.
                --    This reduces what they owe you.
                --
                --    NOTE:
                --    If your settlement direction semantics are:
                --    from = payer
                --    to   = receiver
                --    then this amount should REDUCE the receivable.
                -- ----------------------------------------------------
                COALESCE((
                    SELECT SUM(s.amount_paise)
                    FROM public.settlements s
                    WHERE s.room_id = rm.room_id
                      AND (
                          s.from_user_id = rm.user_id
                          OR s.from_member_name = rm.member_name
                      )
                      AND s.to_user_id = v_user_id
                ), 0)

                -

                -- ----------------------------------------------------
                -- 4. SETTLEMENTS where YOU paid the other person.
                --    This reduces what you owe them / increases
                --    your receivable.
                -- ----------------------------------------------------
                COALESCE((
                    SELECT SUM(s.amount_paise)
                    FROM public.settlements s
                    WHERE s.room_id = rm.room_id
                      AND s.from_user_id = v_user_id
                      AND (
                          s.to_user_id = rm.user_id
                          OR s.to_member_name = rm.member_name
                      )
                ), 0)
            ) AS net_receivable_paise

        FROM public.room_members rm

        JOIN public.rooms r
            ON rm.room_id = r.id

        WHERE rm.room_id IN (
            SELECT room_id
            FROM public.room_members
            WHERE user_id = v_user_id
              AND is_active = TRUE
        )

        -- Don't include yourself.
        AND (
            rm.user_id IS NULL
            OR rm.user_id != v_user_id
        )

        AND rm.is_active = TRUE
    ) sub

    -- ================================================================
    -- ONLY PEOPLE WHO ACTUALLY OWE YOU
    -- ================================================================

    WHERE sub.net_receivable_paise > 0;

    RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------
-- TOOL 5: Get People I Owe (Net Payables)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_people_i_owe()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT 
            rm.member_name AS person_name,
            rm.user_id AS person_user_id,
            r.name AS room_name,
            COALESCE((
                SELECT SUM(es.amount_paise)
                FROM public.room_expenses re
                JOIN public.expense_splits es ON es.room_expense_id = re.id
                WHERE re.room_id = rm.room_id
                  AND (re.paid_by_user_id = rm.user_id OR (re.paid_by_member_name = rm.member_name AND rm.user_id IS NULL))
                  AND es.user_id = v_user_id
            ), 0)
            -
            COALESCE((
                SELECT SUM(es.amount_paise)
                FROM public.room_expenses re
                JOIN public.expense_splits es ON es.room_expense_id = re.id
                WHERE re.room_id = rm.room_id
                  AND re.paid_by_user_id = v_user_id
                  AND (es.user_id = rm.user_id OR (es.member_name = rm.member_name AND rm.user_id IS NULL))
            ), 0)
            +
            COALESCE((
                SELECT SUM(s.amount_paise)
                FROM public.settlements s
                WHERE s.room_id = rm.room_id
                  AND s.from_user_id = v_user_id
                  AND (s.to_user_id = rm.user_id OR s.to_member_name = rm.member_name)
            ), 0)
            -
            COALESCE((
                SELECT SUM(s.amount_paise)
                FROM public.settlements s
                WHERE s.room_id = rm.room_id
                  AND (s.from_user_id = rm.user_id OR s.from_member_name = rm.member_name)
                  AND s.to_user_id = v_user_id
            ), 0) AS net_payable_paise
        FROM public.room_members rm
        JOIN public.rooms r ON rm.room_id = r.id
        WHERE rm.room_id IN (
            SELECT room_id FROM public.room_members WHERE user_id = v_user_id AND is_active = TRUE
        )
        AND (rm.user_id IS NULL OR rm.user_id != v_user_id)
        AND rm.is_active = TRUE
    ) sub
    CROSS JOIN LATERAL (
        SELECT ROUND((sub.net_payable_paise::NUMERIC / 100.0), 2) AS net_payable_rupees
    ) r
    WHERE sub.net_payable_paise > 0
    ORDER BY sub.net_payable_paise DESC;

    RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------
-- TOOL 6: Get Net Balance with Specific Person
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_person_balance(p_target_person_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_paid_for_person BIGINT := 0;
    v_person_paid_for_user BIGINT := 0;
    v_settled_person_to_user BIGINT := 0;
    v_settled_user_to_person BIGINT := 0;
    v_net_paise BIGINT := 0;
    v_status TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    SELECT COALESCE(SUM(es.amount_paise), 0)
    INTO v_user_paid_for_person
    FROM public.room_expenses re
    JOIN public.expense_splits es ON es.room_expense_id = re.id
    WHERE re.paid_by_user_id = v_user_id
      AND LOWER(es.member_name) LIKE '%' || LOWER(p_target_person_name) || '%';

    SELECT COALESCE(SUM(es.amount_paise), 0)
    INTO v_person_paid_for_user
    FROM public.room_expenses re
    JOIN public.expense_splits es ON es.room_expense_id = re.id
    WHERE LOWER(re.paid_by_member_name) LIKE '%' || LOWER(p_target_person_name) || '%'
      AND es.user_id = v_user_id;

    SELECT COALESCE(SUM(amount_paise), 0)
    INTO v_settled_person_to_user
    FROM public.settlements
    WHERE LOWER(from_member_name) LIKE '%' || LOWER(p_target_person_name) || '%'
      AND to_user_id = v_user_id;

    SELECT COALESCE(SUM(amount_paise), 0)
    INTO v_settled_user_to_person
    FROM public.settlements
    WHERE from_user_id = v_user_id
      AND LOWER(to_member_name) LIKE '%' || LOWER(p_target_person_name) || '%';

    v_net_paise := (v_user_paid_for_person - v_settled_person_to_user) - (v_person_paid_for_user - v_settled_user_to_person);

    IF v_net_paise > 0 THEN
        v_status := p_target_person_name || ' owes you ₹' || ROUND((v_net_paise::NUMERIC / 100.0), 2)::TEXT;
    ELSIF v_net_paise < 0 THEN
        v_status := 'You owe ' || p_target_person_name || ' ₹' || ROUND((ABS(v_net_paise)::NUMERIC / 100.0), 2)::TEXT;
    ELSE
        v_status := 'You and ' || p_target_person_name || ' are even.';
    END IF;

    RETURN jsonb_build_object(
        'person_name', p_target_person_name,
        'net_paise', v_net_paise,
        'net_rupees', ROUND((ABS(v_net_paise)::NUMERIC / 100.0), 2),
        'status_summary', v_status,
        'user_paid_upfront_rupees', ROUND((v_user_paid_for_person::NUMERIC / 100.0), 2),
        'person_paid_upfront_rupees', ROUND((v_person_paid_for_user::NUMERIC / 100.0), 2)
    );
END;
$$;

-- ---------------------------------------------------------------------
-- TOOL 7: Get Budget Status & Remaining
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_budget_status(p_month INT DEFAULT NULL, p_year INT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_m INT := COALESCE(p_month, EXTRACT(MONTH FROM NOW())::INT);
    v_y INT := COALESCE(p_year, EXTRACT(YEAR FROM NOW())::INT);
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT 
            b.id AS budget_id,
            COALESCE(c.name, 'Overall') AS category_name,
            b.amount_limit_paise,
            ROUND((b.amount_limit_paise::NUMERIC / 100.0), 2) AS limit_rupees,
            COALESCE(SUM(t.amount_paise), 0) AS spent_paise,
            ROUND((COALESCE(SUM(t.amount_paise), 0)::NUMERIC / 100.0), 2) AS spent_rupees,
            (b.amount_limit_paise - COALESCE(SUM(t.amount_paise), 0)) AS remaining_paise,
            ROUND(((b.amount_limit_paise - COALESCE(SUM(t.amount_paise), 0))::NUMERIC / 100.0), 2) AS remaining_rupees,
            CASE 
                WHEN COALESCE(SUM(t.amount_paise), 0) > b.amount_limit_paise THEN TRUE 
                ELSE FALSE 
            END AS is_over_budget
        FROM public.budgets b
        LEFT JOIN public.categories c ON b.category_id = c.id
        LEFT JOIN public.transactions t ON t.user_id = b.user_id 
            AND t.category_id = b.category_id 
            AND t.type = 'expense'
            AND EXTRACT(MONTH FROM t.date) = v_m
            AND EXTRACT(YEAR FROM t.date) = v_y
        WHERE b.user_id = v_user_id
          AND b.month = v_m
          AND b.year = v_y
        GROUP BY b.id, c.name, b.amount_limit_paise
    ) r;

    RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------
-- TOOL 8: Get Largest Expenses
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_largest_expenses(p_limit INT DEFAULT 5)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT 
            t.id,
            COALESCE(c.name, 'Uncategorized') AS category,
            t.amount_paise,
            ROUND((t.amount_paise::NUMERIC / 100.0), 2) AS amount_rupees,
            t.date,
            COALESCE(t.note, 'Expense') AS note,
            t.payment_method
        FROM public.transactions t
        LEFT JOIN public.categories c ON t.category_id = c.id
        WHERE t.user_id = v_user_id
          AND t.type = 'expense'
        ORDER BY t.amount_paise DESC
        LIMIT p_limit
    ) r;

    RETURN v_result;
END;
$$;

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.match_financial_memory(vector, int, float) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_monthly_spending(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_weekly_spending() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_category_spending(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_people_who_owe_me() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_people_i_owe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_person_balance(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_budget_status(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_largest_expenses(int) TO authenticated;
