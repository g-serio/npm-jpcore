/**
 * Shared types between Admin Engine and Input Registry.
 */
export interface BaseWidgetProps<T = unknown> {
  label: string;
  value: T;
  onChange: (val: T) => void;
  options?: string[];
}
