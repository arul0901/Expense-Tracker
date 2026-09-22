-- =====================================================================
-- PROFIN — AI RAG INGESTION QUEUE
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.ai_ingestion_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trigger_source TEXT NOT NULL, -- e.g., 'transaction_added', 'settlement_changed'
    entity_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ai_ingestion_queue ENABLE ROW LEVEL SECURITY;

-- Note: The Edge Function 'financial-ai-ingest' will process these records.
-- In a real Supabase environment, you would set up a Database Webhook 
-- on INSERT to 'public.ai_ingestion_queue' that calls the Edge Function.

-- ---------------------------------------------------------------------
-- QUEUE TRIGGERS
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.queue_ai_ingestion_on_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.ai_ingestion_queue (user_id, trigger_source, entity_id)
    VALUES (
        COALESCE(NEW.user_id, OLD.user_id), 
        'transaction_changed', 
        COALESCE(NEW.id, OLD.id)
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_transaction_ai_ingest ON public.transactions;
CREATE TRIGGER trigger_transaction_ai_ingest
AFTER INSERT OR UPDATE OR DELETE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.queue_ai_ingestion_on_transaction();

CREATE OR REPLACE FUNCTION public.queue_ai_ingestion_on_room_expense()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.ai_ingestion_queue (user_id, trigger_source, entity_id)
    VALUES (
        COALESCE(NEW.paid_by_user_id, OLD.paid_by_user_id), 
        'room_expense_changed', 
        COALESCE(NEW.id, OLD.id)
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_room_expense_ai_ingest ON public.room_expenses;
CREATE TRIGGER trigger_room_expense_ai_ingest
AFTER INSERT OR UPDATE OR DELETE ON public.room_expenses
FOR EACH ROW EXECUTE FUNCTION public.queue_ai_ingestion_on_room_expense();
