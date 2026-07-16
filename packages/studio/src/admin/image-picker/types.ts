/**
 * Image Picker widget: value shape for schema fields with .describe('ui:image-picker').
 */
export interface ImageSelection {
  url: string;
  alt: string;
}

export const DEFAULT_IMAGE_SELECTION: ImageSelection = { url: '', alt: '' };

export interface ImagePreviewFieldProps {
  value: ImageSelection;
  onChange: (image: ImageSelection) => void;
  label?: string;
  className?: string;
}
