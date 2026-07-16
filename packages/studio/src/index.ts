/**
 * @olonjs/studio — public entry point.
 *
 * The schema-driven Studio editor UI (AdminSidebar, FormFactory, StudioStage,
 * the StudioRouteBody orchestration body). Depends only on `@olonjs/core` —
 * never on `@olonjs/react`. The `@olonjs/react` package reaches this module
 * exclusively via a single dynamic `import('@olonjs/studio')` bridge
 * (`StudioRoute`), so this package's code is absent from any visitor-only
 * bundle.
 */
export { StudioRouteBody, type StudioRouteBodyProps } from './StudioRouteBody';

export { AddSectionLibrary } from './admin/AddSectionLibrary';
export { AdminSidebar, type LayerItem, type OnUpdateSection } from './admin/AdminSidebar';
export { FormFactory } from './admin/FormFactory';
export { InputWidgets, type WidgetType } from './admin/InputRegistry';
export { PageSelector } from './admin/PageSelector';
export { StudioStage } from './admin/StudioStage';
export { buildSelectionPath } from '@olonjs/core';

export {
  ImagePickerDialog,
  ImagePreviewField,
  DEFAULT_IMAGE_SELECTION,
  type ImageSelection,
  type ImagePreviewFieldProps,
} from './admin/image-picker';

export {
  StudioAssetsProvider,
  useStudioAssets,
  type IconRegistry,
  type StudioAssetsContextValue,
} from './context/StudioAssetsContext';

export * from './ui';

// Studio-authored skin CSS, inlined as a string so the `@olonjs/react`
// bridge can inject it via `ThemeLoader` only when the admin route is
// actually mounted (never eagerly bundled by a visitor-only consumer).
// eslint-disable-next-line import/no-unresolved
import adminSkinCss from './admin/admin-skin.css?inline';
export { adminSkinCss };
