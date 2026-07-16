export const STUDIO_EVENTS = {
  UPDATE_DRAFTS: 'jsonpages:update-drafts',
  SYNC_SELECTION: 'jsonpages:sync-selection',
  SECTION_SELECT: 'jsonpages:section-select',
  INLINE_FIELD_UPDATE: 'jsonpages:inline-field-update',
  INLINE_FLUSHED: 'jsonpages:inline-flushed',
  REQUEST_SCROLL_TO_SECTION: 'jsonpages:request-scroll-to-section',
  REQUEST_INLINE_FLUSH: 'jsonpages:request-inline-flush',
  ACTIVE_SECTION_CHANGED: 'jsonpages:active-section-changed',
  STAGE_READY: 'jsonpages:stage-ready',
  WEBMCP_TOOL_CALL: 'olonjs:webmcp:tool-call',
  WEBMCP_TOOL_RESULT: 'olonjs:webmcp:tool-result',
} as const;
