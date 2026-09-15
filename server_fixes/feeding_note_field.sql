-- Add note (fulfillment remark) field to feeding_orders table
-- Non-destructive: uses IF NOT EXISTS guard

ALTER TABLE feeding_orders
  ADD COLUMN IF NOT EXISTS note TEXT DEFAULT NULL COMMENT '履约备注'
  AFTER message;
