import { accessibility } from '@kit.AccessibilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN = 0x0000;
const LOG_TAG = 'TransitA11yStatus';
const EXTENSION_QUERY_TYPES: accessibility.AbilityType[] = ['spoken', 'visual', 'audible', 'haptic', 'generic'];
let touchModeSyncUnsupported = false;
let extensionListSyncUnsupported = false;

export type TouchMode = 'singleTouchMode' | 'doubleTouchMode' | 'none' | 'unknown';
export type StartMode = 'standard' | 'accessible' | 'doubleTouch' | 'fallback';

export interface AccessibilityStatus {
  accessibilityEnabled: boolean;
  touchGuideEnabled: boolean;
  touchMode: TouchMode;
  enabledExtensionCount: number;
  enabledExtensionNames: string[];
  mode: StartMode;
}

/**
 * Creates the initial status shown before the first AccessibilityKit read finishes.
 * The default uses Fallback Mode because API availability is device/runtime dependent.
 */
export function createDefaultAccessibilityStatus(): AccessibilityStatus {
  return {
    accessibilityEnabled: false,
    touchGuideEnabled: false,
    touchMode: 'unknown',
    enabledExtensionCount: 0,
    enabledExtensionNames: [],
    mode: 'fallback'
  };
}

/**
 * Keeps getTouchModeSync() values inside the codelab's supported union.
 * Unknown runtime values are treated as "unknown" so the UI can fall back safely.
 */
export function normalizeTouchMode(value: string): TouchMode {
  if (value === 'singleTouchMode' || value === 'doubleTouchMode' || value === 'none') {
    return value;
  }
  return 'unknown';
}

/**
 * Applies the codelab mode priority:
 * double-touch mode wins, accessibility/touch guide enables accessible mode,
 * unknown touch mode falls back, and no active signal stays standard mode.
 */
export function decideStartMode(
  accessibilityEnabled: boolean,
  touchGuideEnabled: boolean,
  touchMode: TouchMode
): StartMode {
  if (touchMode === 'doubleTouchMode') {
    return 'doubleTouch';
  }
  if (accessibilityEnabled || touchGuideEnabled) {
    return 'accessible';
  }
  if (touchMode === 'unknown') {
    return 'fallback';
  }
  return 'standard';
}

interface LoggedError {
  code?: number;
  message?: string;
  name?: string;
}

/**
 * Converts BusinessError-like objects into stable log text.
 * Some HarmonyOS runtime errors stringify to "{}", so fields are read explicitly.
 */
function formatError(error: Object): string {
  const loggedError = error as LoggedError;
  const code = loggedError.code === undefined ? 'unknown' : `${loggedError.code}`;
  const name = loggedError.name === undefined ? 'unknown' : loggedError.name;
  const message = loggedError.message === undefined ? 'unknown' : loggedError.message;
  return `code=${code}, name=${name}, message=${message}`;
}

/**
 * Detects runtimes where getTouchModeSync() exists in typings but is not callable.
 * Once detected, later refreshes skip the call to keep profiling logs readable.
 */
function isNotCallableError(error: Object): boolean {
  const loggedError = error as LoggedError;
  return loggedError.name === 'TypeError' && loggedError.message !== undefined &&
    loggedError.message.indexOf('callable') >= 0;
}

/**
 * Identifies parameter validation failures returned by extension-list queries.
 * The app uses this to mark unsupported runtime behavior after fallback attempts.
 */
function isParameterError(error: Object): boolean {
  const loggedError = error as LoggedError;
  return loggedError.code === 401;
}

/**
 * Adds a display label for an enabled extension, preferring name, then bundle, then id.
 * Only the first three labels are kept so the watch UI stays compact.
 */
function pushExtensionLabel(
  enabledExtensionNames: string[],
  id: string,
  name: string,
  bundleName: string
): void {
  if (enabledExtensionNames.length >= 3) {
    return;
  }

  let label = name;
  if (label.length === 0) {
    label = bundleName;
  }
  if (label.length === 0) {
    label = id;
  }
  enabledExtensionNames.push(label);
}

/**
 * Reads the current AccessibilityKit state, logs each API call duration, and returns
 * the UI-ready status model used by the route start and walking screens.
 */
export function getAccessibilityStatus(): AccessibilityStatus {
  const totalStart = Date.now();
  let accessibilityEnabled = false;
  let touchGuideEnabled = false;
  let touchMode: TouchMode = 'unknown';
  let enabledExtensionCount = 0;
  let enabledExtensionNames: string[] = [];

  hilog.info(LOG_DOMAIN, LOG_TAG, 'getAccessibilityStatus start');

  let callStart = Date.now();
  try {
    accessibilityEnabled = accessibility.isOpenAccessibilitySync();
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'isOpenAccessibilitySync success result=%{public}s duration=%{public}dms',
      `${accessibilityEnabled}`, Date.now() - callStart);
  } catch (error) {
    accessibilityEnabled = false;
    hilog.error(LOG_DOMAIN, LOG_TAG,
      'isOpenAccessibilitySync failed duration=%{public}dms error=%{public}s',
      Date.now() - callStart, formatError(error));
  }

  callStart = Date.now();
  try {
    touchGuideEnabled = accessibility.isOpenTouchGuideSync();
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'isOpenTouchGuideSync success result=%{public}s duration=%{public}dms',
      `${touchGuideEnabled}`, Date.now() - callStart);
  } catch (error) {
    touchGuideEnabled = false;
    hilog.error(LOG_DOMAIN, LOG_TAG,
      'isOpenTouchGuideSync failed duration=%{public}dms error=%{public}s',
      Date.now() - callStart, formatError(error));
  }

  if (touchModeSyncUnsupported) {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'getTouchModeSync skipped reason=unsupported-runtime fallback=unknown');
  } else {
    callStart = Date.now();
    try {
      touchMode = normalizeTouchMode(accessibility.getTouchModeSync());
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'getTouchModeSync success result=%{public}s duration=%{public}dms',
        touchMode, Date.now() - callStart);
    } catch (error) {
      touchMode = 'unknown';
      if (isNotCallableError(error)) {
        touchModeSyncUnsupported = true;
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'getTouchModeSync unsupported on this runtime duration=%{public}dms fallback=%{public}s error=%{public}s',
          Date.now() - callStart, touchMode, formatError(error));
      } else {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'getTouchModeSync failed duration=%{public}dms fallback=%{public}s error=%{public}s',
          Date.now() - callStart, touchMode, formatError(error));
      }
    }
  }

  if (extensionListSyncUnsupported) {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'getAccessibilityExtensionListSync skipped reason=unsupported-runtime');
  } else {
    callStart = Date.now();
    try {
      const enabledExtensions = accessibility.getAccessibilityExtensionListSync('all', 'enable');
      enabledExtensionCount = enabledExtensions.length;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'getAccessibilityExtensionListSync success count=%{public}d duration=%{public}dms',
        enabledExtensionCount, Date.now() - callStart);

      const previewCount = Math.min(enabledExtensions.length, 3);
      for (let index = 0; index < previewCount; index++) {
        pushExtensionLabel(
          enabledExtensionNames,
          enabledExtensions[index].id,
          enabledExtensions[index].name,
          enabledExtensions[index].bundleName
        );
      }
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'getAccessibilityExtensionListSync(all, enable) failed duration=%{public}dms error=%{public}s',
        Date.now() - callStart, formatError(error));

      callStart = Date.now();
      let fallbackCount = 0;
      let fallbackNames: string[] = [];
      let seenIds: string[] = [];

      try {
        for (let typeIndex = 0; typeIndex < EXTENSION_QUERY_TYPES.length; typeIndex++) {
          const abilityType = EXTENSION_QUERY_TYPES[typeIndex];
          const typedExtensions = accessibility.getAccessibilityExtensionListSync(abilityType, 'enable');

          for (let extensionIndex = 0; extensionIndex < typedExtensions.length; extensionIndex++) {
            const extensionId = typedExtensions[extensionIndex].id;
            if (seenIds.indexOf(extensionId) < 0) {
              seenIds.push(extensionId);
              fallbackCount++;
              pushExtensionLabel(
                fallbackNames,
                extensionId,
                typedExtensions[extensionIndex].name,
                typedExtensions[extensionIndex].bundleName
              );
            }
          }
        }

        enabledExtensionCount = fallbackCount;
        enabledExtensionNames = fallbackNames;
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'getAccessibilityExtensionListSync fallback success count=%{public}d duration=%{public}dms',
          enabledExtensionCount, Date.now() - callStart);
      } catch (fallbackError) {
        enabledExtensionCount = 0;
        enabledExtensionNames = [];
        if (isParameterError(error) && isParameterError(fallbackError)) {
          extensionListSyncUnsupported = true;
          hilog.warn(LOG_DOMAIN, LOG_TAG,
            'getAccessibilityExtensionListSync unsupported on this runtime duration=%{public}dms error=%{public}s',
            Date.now() - callStart, formatError(fallbackError));
        } else {
          hilog.warn(LOG_DOMAIN, LOG_TAG,
            'getAccessibilityExtensionListSync fallback failed duration=%{public}dms error=%{public}s',
            Date.now() - callStart, formatError(fallbackError));
        }
      }
    }
  }

  const mode = decideStartMode(accessibilityEnabled, touchGuideEnabled, touchMode);
  hilog.info(LOG_DOMAIN, LOG_TAG,
    'getAccessibilityStatus complete mode=%{public}s accessibility=%{public}s touchGuide=%{public}s touchMode=%{public}s extensions=%{public}d total=%{public}dms',
    mode, `${accessibilityEnabled}`, `${touchGuideEnabled}`, touchMode, enabledExtensionCount, Date.now() - totalStart);

  return {
    accessibilityEnabled,
    touchGuideEnabled,
    touchMode,
    enabledExtensionCount,
    enabledExtensionNames,
    mode
  };
}
