-- =====================================================================
-- GLOBAL NOTIFICATIONS SCHEMA & TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. NOTIFICATIONS TABLE
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    actor_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
ON public.notifications FOR SELECT
TO authenticated
USING (auth.uid() = recipient_user_id);

DROP POLICY IF EXISTS "Users can update their own notifications (mark as read)" ON public.notifications;
CREATE POLICY "Users can update their own notifications (mark as read)"
ON public.notifications FOR UPDATE
TO authenticated
USING (auth.uid() = recipient_user_id)
WITH CHECK (auth.uid() = recipient_user_id);

-- ---------------------------------------------------------------------
-- 2. TRIGGER FUNCTION: ROOM EXPENSES
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_room_expense_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_room_name TEXT;
    v_member RECORD;
    v_rupees NUMERIC;
BEGIN
    SELECT name INTO v_room_name FROM public.rooms WHERE id = NEW.room_id;
    v_rupees := NEW.amount_paise / 100.0;

    FOR v_member IN 
        SELECT user_id FROM public.room_members 
        WHERE room_id = NEW.room_id AND is_active = TRUE AND user_id != NEW.paid_by_user_id
    LOOP
        INSERT INTO public.notifications (
            recipient_user_id, actor_user_id, room_id, type, title, message, entity_type, entity_id
        ) VALUES (
            v_member.user_id,
            NEW.paid_by_user_id,
            NEW.room_id,
            'room_expense_added',
            'New Room Expense',
            NEW.paid_by_member_name || ' added a room expense of ₹' || v_rupees || ' for ' || NEW.description || ' in ' || v_room_name,
            'room_expense',
            NEW.id
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_room_expense_notification ON public.room_expenses;
CREATE TRIGGER trigger_room_expense_notification
AFTER INSERT ON public.room_expenses
FOR EACH ROW EXECUTE FUNCTION public.notify_room_expense_added();

-- ---------------------------------------------------------------------
-- 3. TRIGGER FUNCTION: EXPENSE SPLITS (When someone splits an expense)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_expense_split_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_expense_description TEXT;
    v_room_id UUID;
    v_room_name TEXT;
    v_paid_by_user_id UUID;
    v_paid_by_name TEXT;
    v_rupees NUMERIC;
BEGIN
    -- Get expense details
    SELECT description, room_id, paid_by_user_id, paid_by_member_name 
    INTO v_expense_description, v_room_id, v_paid_by_user_id, v_paid_by_name
    FROM public.room_expenses WHERE id = NEW.room_expense_id;

    SELECT name INTO v_room_name FROM public.rooms WHERE id = v_room_id;
    v_rupees := NEW.amount_paise / 100.0;

    -- Only notify the person who owes the split (if it's not the person who paid)
    IF NEW.user_id IS NOT NULL AND NEW.user_id != v_paid_by_user_id THEN
        INSERT INTO public.notifications (
            recipient_user_id, actor_user_id, room_id, type, title, message, entity_type, entity_id
        ) VALUES (
            NEW.user_id,
            v_paid_by_user_id,
            v_room_id,
            'expense_split_added',
            'New Split Added',
            v_paid_by_name || ' added a split of ₹' || v_rupees || ' for ' || v_expense_description || ' in ' || v_room_name,
            'expense_split',
            NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_expense_split_notification ON public.expense_splits;
CREATE TRIGGER trigger_expense_split_notification
AFTER INSERT ON public.expense_splits
FOR EACH ROW EXECUTE FUNCTION public.notify_expense_split_added();

-- ---------------------------------------------------------------------
-- 4. TRIGGER FUNCTION: PERSONAL TRANSACTIONS WITH EVENTS
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_transaction_event_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_room_id UUID;
    v_room_name TEXT;
    v_event_name TEXT;
    v_member RECORD;
    v_rupees NUMERIC;
    v_actor_name TEXT;
BEGIN
    -- Only proceed if it's an expense linked to an event
    IF NEW.type = 'expense' AND NEW.event_id IS NOT NULL THEN
        -- Get Event details
        SELECT room_id, name INTO v_room_id, v_event_name FROM public.events WHERE id = NEW.event_id;
        
        -- Get Room details
        IF v_room_id IS NOT NULL THEN
            SELECT name INTO v_room_name FROM public.rooms WHERE id = v_room_id;
            SELECT display_name INTO v_actor_name FROM public.profiles WHERE id = NEW.user_id;
            v_rupees := NEW.amount_paise / 100.0;

            FOR v_member IN 
                SELECT user_id FROM public.room_members 
                WHERE room_id = v_room_id AND is_active = TRUE AND user_id != NEW.user_id
            LOOP
                INSERT INTO public.notifications (
                    recipient_user_id, actor_user_id, room_id, event_id, type, title, message, entity_type, entity_id
                ) VALUES (
                    v_member.user_id,
                    NEW.user_id,
                    v_room_id,
                    NEW.event_id,
                    'personal_expense_event',
                    'Expense Added to Event',
                    v_actor_name || ' added a personal expense of ₹' || v_rupees || ' to ' || v_event_name || ' in ' || v_room_name,
                    'transaction',
                    NEW.id
                );
            END LOOP;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_transaction_event_notification ON public.transactions;
CREATE TRIGGER trigger_transaction_event_notification
AFTER INSERT ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.notify_transaction_event_added();
