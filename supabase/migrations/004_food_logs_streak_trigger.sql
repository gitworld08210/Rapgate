-- Trigger to automatically bump food streak whenever a new food log is inserted
CREATE OR REPLACE FUNCTION public.trg_bump_food_streak()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.bump_food_streak(NEW.user_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_food_log_inserted_bump_streak ON public.food_logs;

CREATE TRIGGER on_food_log_inserted_bump_streak
AFTER INSERT ON public.food_logs
FOR EACH ROW
EXECUTE FUNCTION public.trg_bump_food_streak();
