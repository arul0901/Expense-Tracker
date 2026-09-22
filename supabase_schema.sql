-- =====================================================================
-- PROFIN — PRODUCTION SUPABASE POSTGRESQL SCHEMA
-- FIXED: ROOMS, MEMBERS, INVITES/QR, RLS, EXPENSES, SETTLEMENTS, REALTIME
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. EXTENSIONS
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------
-- 0.1 SCHEMA COLUMN MIGRATIONS (Ensure existing tables have all required columns)
-- ---------------------------------------------------------------------
ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS member_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.room_expenses ADD COLUMN IF NOT EXISTS paid_by_member_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.room_expenses ADD COLUMN IF NOT EXISTS receipt_url TEXT;
ALTER TABLE public.room_activities ADD COLUMN IF NOT EXISTS member_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.expense_splits ADD COLUMN IF NOT EXISTS member_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS from_member_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS to_member_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS upi_id TEXT;
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS confirmed_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS undo_expires_at TIMESTAMPTZ;
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
-- ---------------------------------------------------------------------
-- 1. PROFILES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT NOT NULL DEFAULT '',
    upi_id TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(
            NULLIF(NEW.raw_user_meta_data->>'display_name', ''),
            split_part(COALESCE(NEW.email, ''), '@', 1),
            'User'
        )
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------
-- 2. CATEGORIES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color BIGINT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.categories (id, user_id, name, icon, color, type, is_system) VALUES
('11111111-1111-4111-a111-111111111111', NULL, 'Food & Dining', 'restaurant', 4293212469, 'expense', TRUE),
('22222222-2222-4222-a222-222222222222', NULL, 'Shopping', 'shopping_bag', 4287524010, 'expense', TRUE),
('33333333-3333-4333-a333-333333333333', NULL, 'Transport', 'directions_bus', 4280199400, 'expense', TRUE),
('44444444-4444-4444-a444-444444444444', NULL, 'Bills', 'receipt_long', 4294675456, 'expense', TRUE),
('55555555-5555-4555-a555-555555555555', NULL, 'Entertainment', 'movie', 4292336480, 'expense', TRUE),
('66666666-6666-4666-a666-666666666666', NULL, 'Healthcare', 'medical_services', 4278234305, 'expense', TRUE),
('77777777-7777-4777-a777-777777777777', NULL, 'Education', 'school', 4282331573, 'expense', TRUE),
('88888888-8888-4888-a888-888888888888', NULL, 'Other Expense', 'category', 4285887861, 'expense', TRUE),
('99999999-9999-4999-a999-999999999999', NULL, 'Salary', 'account_balance_wallet', 4282572871, 'income', TRUE),
('aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', NULL, 'Freelance', 'laptop_mac', 4278234305, 'income', TRUE),
('bbbbbbbb-bbbb-4bbb-abbb-bbbbbbbbbbbb', NULL, 'Investments', 'trending_up', 4286378818, 'income', TRUE),
('cccccccc-cccc-4ccc-accc-cccccccccccc', NULL, 'Gifts', 'card_giftcard', 4294826037, 'income', TRUE),
('dddddddd-dddd-4ddd-addd-dddddddddddd', NULL, 'Other Income', 'category', 4278228616, 'income', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------
-- 3. TRANSACTIONS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    date TIMESTAMPTZ NOT NULL,
    note TEXT,
    payment_method TEXT NOT NULL DEFAULT 'upi',
    event_id UUID,
    room_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 4. BUDGETS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
    amount_limit_paise BIGINT NOT NULL CHECK (amount_limit_paise > 0),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INT NOT NULL CHECK (year >= 2024),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_category_month_year
        UNIQUE (user_id, category_id, month, year)
);

-- ---------------------------------------------------------------------
-- 5. FINANCIAL REMINDERS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.financial_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount_paise BIGINT CHECK (amount_paise >= 0),
    due_date TIMESTAMPTZ NOT NULL,
    frequency TEXT NOT NULL DEFAULT 'one_time',
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 6. EVENTS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    budget_paise BIGINT DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'Upcoming',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 7. ROOMS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL DEFAULT 'Trip',
    color_accent BIGINT NOT NULL DEFAULT 955528,
    currency TEXT NOT NULL DEFAULT '₹ INR',
    payment_reminders_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    task_reminders_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    reminder_after_days INT NOT NULL DEFAULT 3,
    event_id UUID REFERENCES public.events(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 8. ROOM MEMBERS
-- A member is an authenticated profile. member_name is a display snapshot.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    member_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'Member'
        CHECK (role IN ('Owner', 'Admin', 'Member')),
    avatar_color BIGINT NOT NULL DEFAULT 3900150,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS unique_room_member_user
ON public.room_members(room_id, user_id)
WHERE user_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- 9. ROOM INVITES
-- Only SHA-256 hashes are stored. Never store the raw QR token.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    role TEXT NOT NULL DEFAULT 'Member'
        CHECK (role IN ('Admin', 'Member')),
    state TEXT NOT NULL DEFAULT 'Active'
        CHECK (state IN ('Active', 'Revoked', 'Expired')),
    max_uses INT CHECK (max_uses IS NULL OR max_uses > 0),
    uses INT NOT NULL DEFAULT 0 CHECK (uses >= 0),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 10. ROOM EXPENSES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    paid_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    paid_by_member_name TEXT NOT NULL DEFAULT '',
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    description TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    split_type TEXT NOT NULL DEFAULT 'equal'
        CHECK (split_type IN ('equal', 'percentage', 'exact', 'shares')),
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    notes TEXT,
    linked_transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 11. EXPENSE SPLITS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expense_splits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_expense_id UUID NOT NULL REFERENCES public.room_expenses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    member_name TEXT NOT NULL DEFAULT '',
    amount_paise BIGINT NOT NULL CHECK (amount_paise >= 0),
    percentage DOUBLE PRECISION,
    shares INT,
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    paid_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_expense_splits_user_expense
ON public.expense_splits(user_id, room_expense_id);

-- ---------------------------------------------------------------------
-- 12. SETTLEMENTS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.settlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    to_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    from_member_name TEXT NOT NULL DEFAULT '',
    to_member_name TEXT NOT NULL DEFAULT '',
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'payment_initiated', 'payment_completed', 'settled')),
    settled_at TIMESTAMPTZ,
    confirmed_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    note TEXT,
    undo_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 13. ROOM TASKS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    assigned_to_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    due_date TIMESTAMPTZ,
    priority TEXT NOT NULL DEFAULT 'Medium',
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 14. ROOM ACTIVITIES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    member_name TEXT NOT NULL DEFAULT '',
    action_type TEXT NOT NULL,
    details TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 15. NOTIFICATION HISTORY
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'general',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 16. USER DEVICES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_fcm UNIQUE (user_id, fcm_token)
);

-- ---------------------------------------------------------------------
-- 18. APP FEEDBACK & COMMUNITY IDEAS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    type TEXT NOT NULL DEFAULT 'Feature Request',
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    impact TEXT NOT NULL DEFAULT '💡 Great Idea',
    status TEXT NOT NULL DEFAULT 'Under Review',
    upvotes INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow insertion of app feedback" ON public.app_feedback;
CREATE POLICY "Allow insertion of app feedback"
ON public.app_feedback FOR INSERT
TO public
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow reading of app feedback" ON public.app_feedback;
CREATE POLICY "Allow reading of app feedback"
ON public.app_feedback FOR SELECT
TO public
USING (true);

-- =====================================================================
-- 2. SECURITY HELPER FUNCTIONS
-- =====================================================================

CREATE OR REPLACE FUNCTION public.is_room_member(p_room_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.room_members rm
        WHERE rm.room_id = p_room_id
          AND rm.user_id = p_user_id
          AND rm.is_active = TRUE
    );
$$;

CREATE OR REPLACE FUNCTION public.is_room_admin(p_room_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.room_members rm
        WHERE rm.room_id = p_room_id
          AND rm.user_id = p_user_id
          AND rm.is_active = TRUE
          AND rm.role IN ('Owner', 'Admin')
    );
$$;

-- Automatically add room creator as Owner.
CREATE OR REPLACE FUNCTION public.add_room_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name TEXT;
BEGIN
    SELECT COALESCE(NULLIF(display_name, ''), split_part(COALESCE(email, ''), '@', 1), 'Owner')
    INTO v_name
    FROM public.profiles
    WHERE id = NEW.created_by;

    INSERT INTO public.room_members (
        room_id, user_id, member_name, role, is_active
    )
    VALUES (
        NEW.id, NEW.created_by, COALESCE(v_name, 'Owner'), 'Owner', TRUE
    )
    ON CONFLICT (room_id, user_id)
    DO UPDATE SET
        is_active = TRUE,
        role = 'Owner',
        member_name = EXCLUDED.member_name;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_room_created_add_owner ON public.rooms;
CREATE TRIGGER on_room_created_add_owner
AFTER INSERT ON public.rooms
FOR EACH ROW EXECUTE FUNCTION public.add_room_owner();

-- Keep updated_at fields current.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_set_updated_at ON public.profiles;
CREATE TRIGGER profiles_set_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS transactions_set_updated_at ON public.transactions;
CREATE TRIGGER transactions_set_updated_at
BEFORE UPDATE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =====================================================================
-- RLS
-- =====================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- Profiles
DROP POLICY IF EXISTS "Public profiles are viewable by authenticated users" ON public.profiles;
CREATE POLICY "Public profiles are viewable by authenticated users"
ON public.profiles FOR SELECT TO authenticated
USING (TRUE);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Categories
DROP POLICY IF EXISTS "Users can view system and own categories" ON public.categories;
CREATE POLICY "Users can view system and own categories"
ON public.categories FOR SELECT TO authenticated
USING (is_system = TRUE OR user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own categories" ON public.categories;
CREATE POLICY "Users can insert own categories"
ON public.categories FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid() AND is_system = FALSE);

DROP POLICY IF EXISTS "Users can update own categories" ON public.categories;
CREATE POLICY "Users can update own categories"
ON public.categories FOR UPDATE TO authenticated
USING (user_id = auth.uid() AND is_system = FALSE)
WITH CHECK (user_id = auth.uid() AND is_system = FALSE);

DROP POLICY IF EXISTS "Users can delete own categories" ON public.categories;
CREATE POLICY "Users can delete own categories"
ON public.categories FOR DELETE TO authenticated
USING (user_id = auth.uid() AND is_system = FALSE);

-- Personal tables
DROP POLICY IF EXISTS "Users can access own transactions" ON public.transactions;
CREATE POLICY "Users can access own transactions"
ON public.transactions FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can access own budgets" ON public.budgets;
CREATE POLICY "Users can access own budgets"
ON public.budgets FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can access own reminders" ON public.financial_reminders;
CREATE POLICY "Users can access own reminders"
ON public.financial_reminders FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can access own events" ON public.events;
CREATE POLICY "Users can access own events"
ON public.events FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Rooms: members & room creator.
DROP POLICY IF EXISTS "Members can view rooms" ON public.rooms;
CREATE POLICY "Members can view rooms"
ON public.rooms FOR SELECT TO authenticated
USING (created_by = auth.uid() OR public.is_room_member(id, auth.uid()));

DROP POLICY IF EXISTS "Users can create rooms" ON public.rooms;
CREATE POLICY "Users can create rooms"
ON public.rooms FOR INSERT TO authenticated
WITH CHECK (auth.uid() IS NOT NULL AND created_by = auth.uid());

DROP POLICY IF EXISTS "Owners can update rooms" ON public.rooms;
CREATE POLICY "Owners can update rooms"
ON public.rooms FOR UPDATE TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "Owners can delete rooms" ON public.rooms;
CREATE POLICY "Owners can delete rooms"
ON public.rooms FOR DELETE TO authenticated
USING (created_by = auth.uid());

-- Room members: any member can view, only owner/admin can manage.
DROP POLICY IF EXISTS "Members can view room members" ON public.room_members;
CREATE POLICY "Members can view room members"
ON public.room_members FOR SELECT TO authenticated
USING (public.is_room_member(room_id, auth.uid()));

DROP POLICY IF EXISTS "Admins can insert room members" ON public.room_members;
DROP POLICY IF EXISTS "Users can insert room members" ON public.room_members;
CREATE POLICY "Users can insert room members"
ON public.room_members FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid() OR public.is_room_admin(room_id, auth.uid()));

DROP POLICY IF EXISTS "Admins can update room members" ON public.room_members;
CREATE POLICY "Admins can update room members"
ON public.room_members FOR UPDATE TO authenticated
USING (public.is_room_admin(room_id, auth.uid()))
WITH CHECK (public.is_room_admin(room_id, auth.uid()));

DROP POLICY IF EXISTS "Admins can delete room members" ON public.room_members;
CREATE POLICY "Admins can delete room members"
ON public.room_members FOR DELETE TO authenticated
USING (public.is_room_admin(room_id, auth.uid()));

-- Invites: only members can see their room's invite records.
-- Raw tokens are never stored in this table.
DROP POLICY IF EXISTS "Members can view room invites" ON public.room_invites;
CREATE POLICY "Members can view room invites"
ON public.room_invites FOR SELECT TO authenticated
USING (public.is_room_member(room_id, auth.uid()));

DROP POLICY IF EXISTS "Admins can create room invites" ON public.room_invites;
CREATE POLICY "Admins can create room invites"
ON public.room_invites FOR INSERT TO authenticated
WITH CHECK (
    created_by = auth.uid()
    AND public.is_room_admin(room_id, auth.uid())
);

DROP POLICY IF EXISTS "Admins can update room invites" ON public.room_invites;
CREATE POLICY "Admins can update room invites"
ON public.room_invites FOR UPDATE TO authenticated
USING (public.is_room_admin(room_id, auth.uid()))
WITH CHECK (public.is_room_admin(room_id, auth.uid()));

DROP POLICY IF EXISTS "Admins can delete room invites" ON public.room_invites;
CREATE POLICY "Admins can delete room invites"
ON public.room_invites FOR DELETE TO authenticated
USING (public.is_room_admin(room_id, auth.uid()));

-- Room expenses
DROP POLICY IF EXISTS "Members can view room expenses" ON public.room_expenses;
CREATE POLICY "Members can view room expenses"
ON public.room_expenses FOR SELECT TO authenticated
USING (public.is_room_member(room_id, auth.uid()));

DROP POLICY IF EXISTS "Members can insert room expenses" ON public.room_expenses;
CREATE POLICY "Members can insert room expenses"
ON public.room_expenses FOR INSERT TO authenticated
WITH CHECK (
    public.is_room_member(room_id, auth.uid())
    AND paid_by_user_id = auth.uid()
);

DROP POLICY IF EXISTS "Members can update room expenses" ON public.room_expenses;
CREATE POLICY "Members can update room expenses"
ON public.room_expenses FOR UPDATE TO authenticated
USING (public.is_room_member(room_id, auth.uid()))
WITH CHECK (public.is_room_member(room_id, auth.uid()));

DROP POLICY IF EXISTS "Members can delete room expenses" ON public.room_expenses;
CREATE POLICY "Members can delete room expenses"
ON public.room_expenses FOR DELETE TO authenticated
USING (public.is_room_member(room_id, auth.uid()));

-- Expense splits
DROP POLICY IF EXISTS "Members can view expense splits" ON public.expense_splits;
CREATE POLICY "Members can view expense splits"
ON public.expense_splits FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.room_expenses re
        WHERE re.id = room_expense_id
          AND public.is_room_member(re.room_id, auth.uid())
    )
);

DROP POLICY IF EXISTS "Members can manage expense splits" ON public.expense_splits;
CREATE POLICY "Members can manage expense splits"
ON public.expense_splits FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.room_expenses re
        WHERE re.id = room_expense_id
          AND public.is_room_member(re.room_id, auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.room_expenses re
        WHERE re.id = room_expense_id
          AND public.is_room_member(re.room_id, auth.uid())
    )
);

-- Settlements
DROP POLICY IF EXISTS "Members can view settlements" ON public.settlements;
CREATE POLICY "Members can view settlements"
ON public.settlements FOR SELECT TO authenticated
USING (public.is_room_member(room_id, auth.uid()));

DROP POLICY IF EXISTS "Members can create settlements" ON public.settlements;
CREATE POLICY "Members can create settlements"
ON public.settlements FOR INSERT TO authenticated
WITH CHECK (
    public.is_room_member(room_id, auth.uid())
    AND (from_user_id = auth.uid() OR to_user_id = auth.uid())
);

DROP POLICY IF EXISTS "Members can update settlements" ON public.settlements;
DROP POLICY IF EXISTS "Members can update own settlements" ON public.settlements;
CREATE POLICY "Members can update settlements"
ON public.settlements FOR UPDATE TO authenticated
USING (
    public.is_room_member(room_id, auth.uid())
    AND (
        to_user_id = auth.uid()
        OR (from_user_id = auth.uid() AND status != 'settled')
    )
)
WITH CHECK (
    public.is_room_member(room_id, auth.uid())
    AND (
        to_user_id = auth.uid()
        OR (from_user_id = auth.uid() AND status != 'settled')
    )
);

DROP POLICY IF EXISTS "Members can delete own settlements" ON public.settlements;
CREATE POLICY "Members can delete own settlements"
ON public.settlements FOR DELETE TO authenticated
USING (from_user_id = auth.uid() OR to_user_id = auth.uid());

-- Trigger to enforce backend authorization for marking a settlement as settled
CREATE OR REPLACE FUNCTION public.enforce_settlement_receiver_confirmation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.status = 'settled' AND OLD.status IS DISTINCT FROM 'settled' THEN
        IF auth.uid() IS NULL OR auth.uid() != OLD.to_user_id THEN
            RAISE EXCEPTION 'Unauthorized: Only the receiver of the settlement can mark it as settled.';
        END IF;
        NEW.settled_at = NOW();
        NEW.confirmed_by_user_id = auth.uid();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_enforce_settlement_receiver ON public.settlements;
CREATE TRIGGER trigger_enforce_settlement_receiver
BEFORE UPDATE ON public.settlements
FOR EACH ROW EXECUTE FUNCTION public.enforce_settlement_receiver_confirmation();

-- Tasks
DROP POLICY IF EXISTS "Members can view room tasks" ON public.room_tasks;
CREATE POLICY "Members can view room tasks"
ON public.room_tasks FOR SELECT TO authenticated
USING (room_id IS NULL OR public.is_room_member(room_id, auth.uid()));

DROP POLICY IF EXISTS "Members can manage room tasks" ON public.room_tasks;
CREATE POLICY "Members can manage room tasks"
ON public.room_tasks FOR ALL TO authenticated
USING (
    created_by = auth.uid()
    OR room_id IS NULL
    OR public.is_room_member(room_id, auth.uid())
)
WITH CHECK (
    created_by = auth.uid()
    OR room_id IS NULL
    OR public.is_room_member(room_id, auth.uid())
);

-- Activities
DROP POLICY IF EXISTS "Members can view room activities" ON public.room_activities;
CREATE POLICY "Members can view room activities"
ON public.room_activities FOR SELECT TO authenticated
USING (public.is_room_member(room_id, auth.uid()));

DROP POLICY IF EXISTS "Members can insert room activities" ON public.room_activities;
CREATE POLICY "Members can insert room activities"
ON public.room_activities FOR INSERT TO authenticated
WITH CHECK (public.is_room_member(room_id, auth.uid()));

-- Notifications
DROP POLICY IF EXISTS "Users can manage own notifications" ON public.notification_history;
CREATE POLICY "Users can manage own notifications"
ON public.notification_history FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Devices
DROP POLICY IF EXISTS "Users can manage own device tokens" ON public.user_devices;
CREATE POLICY "Users can manage own device tokens"
ON public.user_devices FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- =====================================================================
-- INVITE / QR FUNCTIONS
-- =====================================================================

-- Create a raw invite token in the application, then call this RPC with it.
-- The database stores only the SHA-256 hash.
CREATE OR REPLACE FUNCTION public.create_room_invite(
    p_room_id UUID,
    p_raw_token TEXT,
    p_role TEXT DEFAULT 'Member',
    p_expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
    p_max_uses INT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF NOT public.is_room_admin(p_room_id, auth.uid()) THEN
        RAISE EXCEPTION 'Only room owners/admins can create invites';
    END IF;

    IF p_role NOT IN ('Admin', 'Member') THEN
        RAISE EXCEPTION 'Invalid invite role';
    END IF;

    IF p_raw_token IS NULL OR length(trim(p_raw_token)) < 16 THEN
        RAISE EXCEPTION 'Invalid invite token';
    END IF;

    INSERT INTO public.room_invites (
        room_id,
        token_hash,
        created_by,
        role,
        expires_at,
        max_uses
    )
    VALUES (
        p_room_id,
        encode(sha256(convert_to(p_raw_token, 'UTF8')), 'hex'),
        auth.uid(),
        p_role,
        p_expires_at,
        p_max_uses
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- Find a room from a raw QR token without exposing the invite table.
CREATE OR REPLACE FUNCTION public.get_room_by_invite_token(p_token TEXT)
RETURNS SETOF public.rooms
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT r.*
    FROM public.rooms r
    JOIN public.room_invites ri ON ri.room_id = r.id
    WHERE (
        ri.token_hash = trim(p_token)
        OR ri.token_hash = UPPER(trim(p_token))
        OR ri.token_hash = encode(sha256(convert_to(trim(p_token), 'UTF8')), 'hex')
    )
      AND ri.state = 'Active'
      AND ri.expires_at > NOW()
      AND (ri.max_uses IS NULL OR ri.uses < ri.max_uses)
    LIMIT 1;
$$;

-- Redeem invite atomically.
CREATE OR REPLACE FUNCTION public.redeem_room_invite(
    p_token TEXT,
    p_member_name TEXT DEFAULT 'Member'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invite public.room_invites%ROWTYPE;
    v_user_id UUID;
    v_clean_name TEXT;
    v_existing_id UUID;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    v_clean_name := COALESCE(NULLIF(TRIM(p_member_name), ''), 'Member');

    -- Lock the invite row so two simultaneous scans cannot over-redeem it.
    SELECT *
    INTO v_invite
    FROM public.room_invites
    WHERE (
        token_hash = trim(p_token)
        OR token_hash = UPPER(trim(p_token))
        OR token_hash = encode(sha256(convert_to(trim(p_token), 'UTF8')), 'hex')
    )
      AND state = 'Active'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or inactive invite token';
    END IF;

    IF v_invite.expires_at <= NOW() THEN
        UPDATE public.room_invites
        SET state = 'Expired'
        WHERE id = v_invite.id;

        RAISE EXCEPTION 'Invite token has expired';
    END IF;

    IF v_invite.max_uses IS NOT NULL
       AND v_invite.uses >= v_invite.max_uses THEN
        UPDATE public.room_invites
        SET state = 'Revoked'
        WHERE id = v_invite.id;

        RAISE EXCEPTION 'Invite token maximum uses reached';
    END IF;

    -- If the user is already a member, do not create a duplicate row.
    SELECT id
    INTO v_existing_id
    FROM public.room_members
    WHERE room_id = v_invite.room_id
      AND user_id = v_user_id
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        UPDATE public.room_members
        SET is_active = TRUE,
            member_name = v_clean_name
        WHERE id = v_existing_id;

        RETURN v_invite.room_id;
    END IF;

    INSERT INTO public.room_members (
        room_id,
        user_id,
        member_name,
        role,
        is_active
    )
    VALUES (
        v_invite.room_id,
        v_user_id,
        v_clean_name,
        v_invite.role,
        TRUE
    );

    UPDATE public.room_invites
    SET uses = uses + 1,
        state = CASE
            WHEN max_uses IS NOT NULL AND uses + 1 >= max_uses
            THEN 'Revoked'
            ELSE state
        END
    WHERE id = v_invite.id;

    BEGIN
        INSERT INTO public.room_activities (
            room_id,
            user_id,
            member_name,
            action_type,
            details
        )
        VALUES (
            v_invite.room_id,
            v_user_id,
            v_clean_name,
            'member_joined',
            v_clean_name || ' joined via invite'
        );
    EXCEPTION WHEN OTHERS THEN
        -- Prevent activity logging errors from aborting successful invite redemptions
        NULL;
    END;

    RETURN v_invite.room_id;
END;
$$;

-- Revoke an invite.
CREATE OR REPLACE FUNCTION public.revoke_room_invite(p_invite_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_room_id UUID;
BEGIN
    SELECT room_id
    INTO v_room_id
    FROM public.room_invites
    WHERE id = p_invite_id;

    IF v_room_id IS NULL THEN
        RAISE EXCEPTION 'Invite not found';
    END IF;

    IF NOT public.is_room_admin(v_room_id, auth.uid()) THEN
        RAISE EXCEPTION 'Only room owners/admins can revoke invites';
    END IF;

    UPDATE public.room_invites
    SET state = 'Revoked'
    WHERE id = p_invite_id;

    RETURN TRUE;
END;
$$;

-- =====================================================================
-- ATOMIC EXPENSE RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.create_room_expense_with_splits(
    p_room_id UUID,
    p_description TEXT,
    p_amount_paise BIGINT,
    p_split_type TEXT,
    p_category_id UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_splits JSONB DEFAULT '[]'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_expense_id UUID;
    v_split JSONB;
    v_split_user UUID;
    v_split_amount BIGINT;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_room_member(p_room_id, v_user_id) THEN
        RAISE EXCEPTION 'User is not a member of this room';
    END IF;

    IF p_amount_paise IS NULL OR p_amount_paise <= 0 THEN
        RAISE EXCEPTION 'Expense amount must be greater than zero';
    END IF;

    IF p_split_type NOT IN ('equal', 'percentage', 'exact', 'shares') THEN
        RAISE EXCEPTION 'Invalid split type';
    END IF;

    INSERT INTO public.room_expenses (
        room_id,
        paid_by_user_id,
        paid_by_member_name,
        amount_paise,
        description,
        split_type,
        category_id,
        notes
    )
    SELECT
        p_room_id,
        v_user_id,
        COALESCE(NULLIF(TRIM(p.display_name), ''), 'Member'),
        p_amount_paise,
        p_description,
        p_split_type,
        p_category_id,
        p_notes
    FROM public.profiles p
    WHERE p.id = v_user_id
    RETURNING id INTO v_expense_id;

    FOR v_split IN
        SELECT value FROM jsonb_array_elements(p_splits)
    LOOP
        v_split_user := NULLIF(v_split->>'user_id', '')::UUID;
        v_split_amount := COALESCE(NULLIF(v_split->>'amount_paise', '')::BIGINT, 0);

        IF v_split_user IS NOT NULL
           AND NOT public.is_room_member(p_room_id, v_split_user) THEN
            RAISE EXCEPTION 'Split user is not a member of this room';
        END IF;

        INSERT INTO public.expense_splits (
            room_expense_id,
            user_id,
            member_name,
            amount_paise,
            percentage,
            shares,
            is_paid,
            paid_at
        )
        SELECT
            v_expense_id,
            v_split_user,
            COALESCE(
                NULLIF(TRIM(rm.member_name), ''),
                NULLIF(TRIM(p.display_name), ''),
                'Member'
            ),
            v_split_amount,
            NULLIF(v_split->>'percentage', '')::DOUBLE PRECISION,
            NULLIF(v_split->>'shares', '')::INT,
            COALESCE(NULLIF(v_split->>'is_paid', '')::BOOLEAN, v_split_user = v_user_id),
            CASE
                WHEN COALESCE(NULLIF(v_split->>'is_paid', '')::BOOLEAN, v_split_user = v_user_id)
                THEN NOW()
                ELSE NULL
            END
        FROM (SELECT 1) x
        LEFT JOIN public.room_members rm
            ON rm.room_id = p_room_id
           AND rm.user_id = v_split_user
           AND rm.is_active = TRUE
        LEFT JOIN public.profiles p
            ON p.id = v_split_user;
    END LOOP;

    INSERT INTO public.room_activities (
        room_id, user_id, member_name, action_type, details
    )
    SELECT
        p_room_id,
        v_user_id,
        COALESCE(NULLIF(TRIM(p.display_name), ''), 'Member'),
        'expense_created',
        'Added expense: ' || p_description
    FROM public.profiles p
    WHERE p.id = v_user_id;

    RETURN v_expense_id;
END;
$$;

-- =====================================================================
-- MEMBER FINANCIAL SUMMARY
-- Calculates each member's share, paid amount and current amount owed.
-- "Owe" = unpaid expense shares minus settlements paid by that member.
-- =====================================================================

CREATE OR REPLACE VIEW public.member_financial_summary
WITH (security_invoker = true)
AS
WITH members AS (
    SELECT
        rm.id AS room_member_id,
        rm.room_id,
        rm.user_id,
        rm.member_name,
        rm.role,
        rm.is_active
    FROM public.room_members rm
),
shares AS (
    SELECT
        es.user_id,
        re.room_id,
        COALESCE(SUM(es.amount_paise), 0)::BIGINT AS total_share_paise,
        COALESCE(
            SUM(CASE WHEN es.is_paid THEN es.amount_paise ELSE 0 END),
            0
        )::BIGINT AS total_paid_paise
    FROM public.expense_splits es
    JOIN public.room_expenses re ON re.id = es.room_expense_id
    GROUP BY es.user_id, re.room_id
),
settlement_paid AS (
    SELECT
        s.from_user_id AS user_id,
        s.room_id,
        COALESCE(SUM(s.amount_paise), 0)::BIGINT AS paid_in_settlements_paise
    FROM public.settlements s
    GROUP BY s.from_user_id, s.room_id
),
settlement_received AS (
    SELECT
        s.to_user_id AS user_id,
        s.room_id,
        COALESCE(SUM(s.amount_paise), 0)::BIGINT AS received_in_settlements_paise
    FROM public.settlements s
    GROUP BY s.to_user_id, s.room_id
)
SELECT
    m.room_member_id,
    m.room_id,
    m.user_id,
    m.member_name,
    m.role,
    m.is_active,
    COALESCE(sh.total_share_paise, 0)::BIGINT AS total_dues_paise,
    COALESCE(sh.total_paid_paise, 0)::BIGINT AS total_paid_paise,
    COALESCE(sp.paid_in_settlements_paise, 0)::BIGINT AS settlements_paid_paise,
    COALESCE(sr.received_in_settlements_paise, 0)::BIGINT AS settlements_received_paise,
    GREATEST(
        0,
        COALESCE(sh.total_share_paise, 0)
        - COALESCE(sh.total_paid_paise, 0)
        - COALESCE(sp.paid_in_settlements_paise, 0)
    )::BIGINT AS owe_paise
FROM members m
LEFT JOIN shares sh
    ON sh.room_id = m.room_id
   AND sh.user_id = m.user_id
LEFT JOIN settlement_paid sp
    ON sp.room_id = m.room_id
   AND sp.user_id = m.user_id
LEFT JOIN settlement_received sr
    ON sr.room_id = m.room_id
   AND sr.user_id = m.user_id;

-- =====================================================================
-- INDEXES
-- =====================================================================

CREATE INDEX IF NOT EXISTS idx_transactions_user_id
ON public.transactions(user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_date
ON public.transactions(date DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_room_id
ON public.transactions(room_id);

CREATE INDEX IF NOT EXISTS idx_budgets_user_id
ON public.budgets(user_id);

CREATE INDEX IF NOT EXISTS idx_financial_reminders_user_id
ON public.financial_reminders(user_id);

CREATE INDEX IF NOT EXISTS idx_events_user_id
ON public.events(user_id);

CREATE INDEX IF NOT EXISTS idx_rooms_created_by
ON public.rooms(created_by);

CREATE INDEX IF NOT EXISTS idx_room_members_room_id
ON public.room_members(room_id);

CREATE INDEX IF NOT EXISTS idx_room_members_user_id
ON public.room_members(user_id);

CREATE INDEX IF NOT EXISTS idx_room_invites_room_id
ON public.room_invites(room_id);

CREATE INDEX IF NOT EXISTS idx_room_invites_state
ON public.room_invites(state);

CREATE INDEX IF NOT EXISTS idx_room_expenses_room_id
ON public.room_expenses(room_id);

CREATE INDEX IF NOT EXISTS idx_expense_splits_expense_id
ON public.expense_splits(room_expense_id);

CREATE INDEX IF NOT EXISTS idx_expense_splits_user_id
ON public.expense_splits(user_id);

CREATE INDEX IF NOT EXISTS idx_settlements_room_id
ON public.settlements(room_id);

CREATE INDEX IF NOT EXISTS idx_room_tasks_room_id
ON public.room_tasks(room_id);

CREATE INDEX IF NOT EXISTS idx_room_activities_room_id
ON public.room_activities(room_id);

-- =====================================================================
-- FUNCTION EXECUTION PERMISSIONS
-- =====================================================================

REVOKE ALL ON FUNCTION public.create_room_invite(UUID, TEXT, TEXT, TIMESTAMPTZ, INT)
FROM PUBLIC;

REVOKE ALL ON FUNCTION public.get_room_by_invite_token(TEXT)
FROM PUBLIC;

REVOKE ALL ON FUNCTION public.redeem_room_invite(TEXT, TEXT)
FROM PUBLIC;

REVOKE ALL ON FUNCTION public.revoke_room_invite(UUID)
FROM PUBLIC;

REVOKE ALL ON FUNCTION public.create_room_expense_with_splits(
    UUID, TEXT, BIGINT, TEXT, UUID, TEXT, JSONB
)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_room_invite(UUID, TEXT, TEXT, TIMESTAMPTZ, INT)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_room_by_invite_token(TEXT)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.redeem_room_invite(TEXT, TEXT)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.revoke_room_invite(UUID)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_room_expense_with_splits(
    UUID, TEXT, BIGINT, TEXT, UUID, TEXT, JSONB
)
TO authenticated;

-- =====================================================================
-- REALTIME
-- =====================================================================
-- Safe/idempotent helper: only add tables not already present.
DO $$
DECLARE
    v_table TEXT;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        FOREACH v_table IN ARRAY ARRAY[
            'rooms',
            'room_members',
            'room_invites',
            'room_expenses',
            'expense_splits',
            'settlements',
            'room_tasks',
            'room_activities'
        ]
        LOOP
            IF NOT EXISTS (
                SELECT 1
                FROM pg_publication_tables
                WHERE pubname = 'supabase_realtime'
                  AND schemaname = 'public'
                  AND tablename = v_table
            ) THEN
                EXECUTE format(
                    'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
                    v_table
                );
            END IF;
        END LOOP;
    END IF;
END;
$$;

-- =====================================================================
-- SUPABASE STORAGE: BILL RECEIPTS BUCKET
-- =====================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', true)
ON CONFLICT (id) DO NOTHING;

-- Policy: Allow authenticated users to upload receipts
DROP POLICY IF EXISTS "Allow authenticated users to upload receipts" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'receipts');

-- Policy: Allow public read access to bill receipts
DROP POLICY IF EXISTS "Allow public read access to receipts" ON storage.objects;
CREATE POLICY "Allow public read access to receipts"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'receipts');

-- =====================================================================
-- OPTIONAL: RELOAD POSTGREST SCHEMA CACHE
-- =====================================================================
NOTIFY pgrst, 'reload schema';

-- =====================================================================
-- END
-- =====================================================================
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
