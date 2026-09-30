#!/usr/bin/env node
/**
 * Bangkok Weather Resilience & Disaster Preparedness System
 * Empirical Challenger Verification Suite: LIFF Deep Linking & Parameter Synchronization Edge Cases
 * 
 * Verifies:
 * - Suite 1: Malformed Query Strings & Missing Keys
 * - Suite 2: Nested LINE liff.state Encodings & URI Resilience
 * - Suite 3: Hash Fragments & SPA Routing
 * - Suite 4: Dynamic Event Listeners & hashchange Reactivity
 * - Suite 5: #card-hazard Scroll & Apple Spatial Pulse Ring Lifecycle
 * - Suite 6: HTML & CSS Contract Verification
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const htmlPath = path.resolve(__dirname, '../gateway/static/liff/index.html');
assert(fs.existsSync(htmlPath), `Static LIFF file not found at ${htmlPath}`);
const htmlContent = fs.readFileSync(htmlPath, 'utf8');

// Extract script
const scriptMatch = htmlContent.match(/<script>([\s\S]*?)<\/script>/);
assert(scriptMatch, "Failed to find <script> in index.html");
const jsCode = scriptMatch[1];

// Helper to create mock DOM element
function createMockElement(id, initialClasses = '') {
  let classes = initialClasses.split(/\s+/).filter(Boolean);
  let reflowCount = 0;
  return {
    id,
    classList: {
      add: (...c) => {
        c.forEach(item => {
          if (item && !classes.includes(item)) classes.push(item);
        });
      },
      remove: (...c) => {
        classes = classes.filter(item => !c.includes(item));
      },
      contains: (c) => classes.includes(c),
    },
    get className() { return classes.join(' '); },
    set className(val) { classes = (val || '').split(/\s+/).filter(Boolean); },
    innerHTML: '',
    innerText: '',
    get offsetWidth() {
      reflowCount++;
      return 100;
    },
    get reflowCount() { return reflowCount; },
    scrollIntoViewCalled: false,
    scrollIntoViewOptions: null,
    scrollIntoView: function(opts) {
      this.scrollIntoViewCalled = true;
      this.scrollIntoViewOptions = opts;
    },
    style: {}
  };
}

// Timer simulator for accurate async lifecycle assertions
class MockTimerManager {
  constructor() {
    this.timers = [];
    this.currentTime = 0;
  }

  setTimeout(fn, delay) {
    const id = this.timers.length + 1;
    this.timers.push({ id, fn, triggerAt: this.currentTime + delay, cleared: false });
    return id;
  }

  clearTimeout(id) {
    const t = this.timers.find(x => x.id === id);
    if (t) t.cleared = true;
  }

  advance(ms) {
    this.currentTime += ms;
    for (const t of this.timers) {
      if (!t.cleared && t.triggerAt <= this.currentTime) {
        t.cleared = true;
        t.fn();
      }
    }
  }
}

function setupMockEnvironment(search = '', hash = '') {
  const elements = {
    'tab-dashboard': createMockElement('tab-dashboard', 'flex-1 px-6 py-2 space-y-3.5'),
    'tab-calendar': createMockElement('tab-calendar', 'hidden flex-1 px-6 py-2'),
    'tab-profile': createMockElement('tab-profile', 'hidden flex-1 px-6 py-2'),
    'nav-dashboard': createMockElement('nav-dashboard', 'bg-white/15 text-white font-semibold'),
    'nav-calendar': createMockElement('nav-calendar', 'text-white/60'),
    'nav-profile': createMockElement('nav-profile', 'text-white/60'),
    'btn-v-sedan': createMockElement('btn-v-sedan', 'border-2 border-cyan-400 bg-cyan-500/20'),
    'btn-v-moto': createMockElement('btn-v-moto', 'apple-glass-subtle'),
    'btn-v-pickup': createMockElement('btn-v-pickup', 'apple-glass-subtle'),
    'btn-v-transit': createMockElement('btn-v-transit', 'apple-glass-subtle'),
    'badge-vehicle': createMockElement('badge-vehicle'),
    'card-hazard': createMockElement('card-hazard', 'rounded-3xl p-4 apple-glass'),
  };
  elements['badge-vehicle'].innerHTML = '🚗 รถเก๋งเตี้ย';

  const listeners = {};
  const mockWindow = {
    location: {
      search: search || '',
      hash: hash || '',
    },
    addEventListener: (evt, fn) => {
      if (!listeners[evt]) listeners[evt] = [];
      listeners[evt].push(fn);
    },
    dispatchEvent: (evt) => {
      if (listeners[evt]) {
        listeners[evt].forEach(fn => fn());
      }
    }
  };

  const timerManager = new MockTimerManager();

  const mockDocument = {
    readyState: 'complete',
    getElementById: (id) => elements[id] || null,
    addEventListener: (evt, fn) => {
      if (!listeners[evt]) listeners[evt] = [];
      listeners[evt].push(fn);
    },
  };

  const sandbox = {
    window: mockWindow,
    document: mockDocument,
    console: {
      log: () => {},
      warn: () => {},
      error: () => {},
    },
    URLSearchParams: URLSearchParams,
    decodeURIComponent: decodeURIComponent,
    setTimeout: (fn, delay) => timerManager.setTimeout(fn, delay),
    clearTimeout: (id) => timerManager.clearTimeout(id),
  };

  vm.createContext(sandbox);
  vm.runInContext(jsCode, sandbox);

  return {
    elements,
    mockWindow,
    mockDocument,
    sandbox,
    timerManager,
    listeners
  };
}

let totalTests = 0;
let passedTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  [PASS] Test ${totalTests}: ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  [FAIL] Test ${totalTests}: ${name}`);
    console.error(`         ${err.message}`);
    throw err;
  }
}

console.log("============================================================================");
console.log(" EMPIRICAL CHALLENGER: LIFF DEEP LINKING & PARAMETER SYNCHRONIZATION TESTS  ");
console.log("============================================================================");

// ============================================================================
// SUITE 1: Query String Parsing & Malformed Inputs
// ============================================================================
console.log("\n=== SUITE 1: Query String Parsing & Malformed Inputs ===");

runTest("Empty search query string defaults to dashboard and sedan", () => {
  const { elements } = setupMockEnvironment("", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'), "dashboard tab should be active");
  assert(elements['tab-calendar'].classList.contains('hidden'), "calendar tab should be hidden");
  assert(elements['btn-v-sedan'].className.includes('border-cyan-400'), "sedan button should be active");
});

runTest("Standalone question mark '?' defaults cleanly", () => {
  const { elements } = setupMockEnvironment("?", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
  assert(elements['btn-v-sedan'].className.includes('border-cyan-400'));
});

runTest("Multiple question marks '???' handled without crash", () => {
  const { elements } = setupMockEnvironment("???", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
});

runTest("Empty delimiters '?&&&&' handled cleanly", () => {
  const { elements } = setupMockEnvironment("?&&&&", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
});

runTest("Query key without value or equals '?tab' defaults to dashboard", () => {
  const { elements } = setupMockEnvironment("?tab", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
});

runTest("Query keys with empty values '?tab=&vehicle=&focus=' keep defaults", () => {
  const { elements } = setupMockEnvironment("?tab=&vehicle=&focus=", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
  assert(elements['btn-v-sedan'].className.includes('border-cyan-400'));
  assert(!elements['card-hazard'].scrollIntoViewCalled);
});

runTest("Invalid tab value '?tab=invalid_foo' falls back to dashboard", () => {
  const { elements } = setupMockEnvironment("?tab=invalid_foo", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
  assert(elements['tab-calendar'].classList.contains('hidden'));
});

runTest("Invalid vehicle value '?vehicle=airplane' falls back to sedan", () => {
  const { elements } = setupMockEnvironment("?vehicle=airplane", "");
  assert(elements['btn-v-sedan'].className.includes('border-cyan-400'));
  assert(!elements['btn-v-moto'].className.includes('border-cyan-400'));
});

runTest("URL encoded parameters: tab=calendar, vehicle=moto", () => {
  const { elements } = setupMockEnvironment("?tab=%63%61%6C%65%6E%64%61%72&vehicle=%6D%6F%74%6F", "");
  assert(!elements['tab-calendar'].classList.contains('hidden'));
  assert(elements['btn-v-moto'].className.includes('border-cyan-400'));
});

runTest("Extra leading, trailing, and duplicate ampersands '?&&tab=calendar&&vehicle=pickup&&'", () => {
  const { elements } = setupMockEnvironment("?&&tab=calendar&&vehicle=pickup&&", "");
  assert(!elements['tab-calendar'].classList.contains('hidden'));
  assert(elements['btn-v-pickup'].className.includes('border-cyan-400'));
});

runTest("Duplicate keys '?tab=calendar&tab=profile' resolves cleanly", () => {
  const { elements } = setupMockEnvironment("?tab=calendar&tab=profile", "");
  assert(!elements['tab-profile'].classList.contains('hidden'));
});

runTest("Unrelated query parameters '?lang=th&theme=dark&utm_source=line' ignored", () => {
  const { elements } = setupMockEnvironment("?lang=th&theme=dark&utm_source=line", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
  assert(elements['btn-v-sedan'].className.includes('border-cyan-400'));
});

runTest("Thai UTF-8 characters in query string '?location=%E0%B8%AD%E0%B9%82%E0%B8%A8%E0%B8%81&tab=profile'", () => {
  const { elements } = setupMockEnvironment("?location=%E0%B8%AD%E0%B9%82%E0%B8%A8%E0%B8%81&tab=profile", "");
  assert(!elements['tab-profile'].classList.contains('hidden'));
});

// ============================================================================
// SUITE 2: Nested LINE liff.state Encodings & URI Resilience
// ============================================================================
console.log("\n=== SUITE 2: Nested LINE liff.state Encodings & URI Resilience ===");

runTest("Standard encoded liff.state: ?liff.state=%3Ftab%3Dcalendar%26vehicle%3Dmoto", () => {
  const { elements } = setupMockEnvironment("?liff.state=%3Ftab%3Dcalendar%26vehicle%3Dmoto", "");
  assert(!elements['tab-calendar'].classList.contains('hidden'));
  assert(elements['btn-v-moto'].className.includes('border-cyan-400'));
  assert(elements['badge-vehicle'].innerHTML.includes("มอเตอร์ไซค์"));
});

runTest("Encoded liff.state with path prefix: ?liff.state=%2Fliff%3Ftab%3Dprofile%26vehicle%3Dpickup", () => {
  const { elements } = setupMockEnvironment("?liff.state=%2Fliff%3Ftab%3Dprofile%26vehicle%3Dpickup", "");
  assert(!elements['tab-profile'].classList.contains('hidden'));
  assert(elements['btn-v-pickup'].className.includes('border-cyan-400'));
  assert(elements['badge-vehicle'].innerHTML.includes("กระบะ"));
});

runTest("Encoded liff.state with path without slash: ?liff.state=liff%3Ftab%3Dcalendar%26vehicle%3Dtransit", () => {
  const { elements } = setupMockEnvironment("?liff.state=liff%3Ftab%3Dcalendar%26vehicle%3Dtransit", "");
  assert(!elements['tab-calendar'].classList.contains('hidden'));
  assert(elements['btn-v-transit'].className.includes('border-cyan-400'));
  assert(elements['badge-vehicle'].innerHTML.includes("รถไฟฟ้า"));
});

runTest("Direct query params inside liff.state without question mark: ?liff.state=tab%3Dprofile%26vehicle%3Dmoto", () => {
  const { elements } = setupMockEnvironment("?liff.state=tab%3Dprofile%26vehicle%3Dmoto", "");
  assert(!elements['tab-profile'].classList.contains('hidden'));
  assert(elements['btn-v-moto'].className.includes('border-cyan-400'));
});

runTest("Encoded liff.state containing fragment: ?liff.state=%23tab%3Dcalendar%26vehicle%3Dmoto", () => {
  const { elements } = setupMockEnvironment("?liff.state=%23tab%3Dcalendar%26vehicle%3Dmoto", "");
  assert(!elements['tab-calendar'].classList.contains('hidden'));
  assert(elements['btn-v-moto'].className.includes('border-cyan-400'));
});

runTest("Outer search params overridden by inner liff.state: ?vehicle=sedan&liff.state=%3Fvehicle%3Dpickup", () => {
  const { elements } = setupMockEnvironment("?vehicle=sedan&liff.state=%3Fvehicle%3Dpickup", "");
  assert(elements['btn-v-pickup'].className.includes('border-cyan-400'), "inner liff.state should take precedence");
  assert(!elements['btn-v-sedan'].className.includes('border-cyan-400'));
});

runTest("Malformed URI in liff.state '?liff.state=%ZZinvalid%FF' caught cleanly", () => {
  const { elements } = setupMockEnvironment("?liff.state=%ZZinvalid%FF", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
  assert(elements['btn-v-sedan'].className.includes('border-cyan-400'));
});

runTest("Truncated URI percent in liff.state '?liff.state=%' caught cleanly", () => {
  const { elements } = setupMockEnvironment("?liff.state=%", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
});

runTest("Empty liff.state '?liff.state=' does not corrupt state", () => {
  const { elements } = setupMockEnvironment("?liff.state=", "");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
  assert(elements['btn-v-sedan'].className.includes('border-cyan-400'));
});

// ============================================================================
// SUITE 3: Hash Fragments & SPA Routing
// ============================================================================
console.log("\n=== SUITE 3: Hash Fragments & SPA Routing ===");

runTest("Direct hash query: #tab=calendar&vehicle=moto", () => {
  const { elements } = setupMockEnvironment("", "#tab=calendar&vehicle=moto");
  assert(!elements['tab-calendar'].classList.contains('hidden'));
  assert(elements['btn-v-moto'].className.includes('border-cyan-400'));
});

runTest("Hash with leading slash: #/tab=profile&vehicle=pickup", () => {
  const { elements } = setupMockEnvironment("", "#/tab=profile&vehicle=pickup");
  assert(!elements['tab-profile'].classList.contains('hidden'));
  assert(elements['btn-v-pickup'].className.includes('border-cyan-400'));
});

runTest("Hash with shebang: #!/tab=calendar&vehicle=transit", () => {
  const { elements } = setupMockEnvironment("", "#!/tab=calendar&vehicle=transit");
  assert(!elements['tab-calendar'].classList.contains('hidden'));
  assert(elements['btn-v-transit'].className.includes('border-cyan-400'));
});

runTest("Hash with path and question mark: #/view?tab=profile&vehicle=moto", () => {
  const { elements } = setupMockEnvironment("", "#/view?tab=profile&vehicle=moto");
  assert(!elements['tab-profile'].classList.contains('hidden'));
  assert(elements['btn-v-moto'].className.includes('border-cyan-400'));
});

runTest("Hash containing encoded liff.state: #liff.state=%3Ftab%3Dprofile%26vehicle%3Dtransit", () => {
  const { elements } = setupMockEnvironment("", "#liff.state=%3Ftab%3Dprofile%26vehicle%3Dtransit");
  assert(!elements['tab-profile'].classList.contains('hidden'));
  assert(elements['btn-v-transit'].className.includes('border-cyan-400'));
});

runTest("Hash parameter overriding search query: search=?tab=calendar, hash=#tab=profile", () => {
  const { elements } = setupMockEnvironment("?tab=calendar", "#tab=profile");
  assert(!elements['tab-profile'].classList.contains('hidden'), "hash tab should override search tab");
});

runTest("Malformed hash '###' handled safely", () => {
  const { elements } = setupMockEnvironment("", "###");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));
});

// ============================================================================
// SUITE 4: Dynamic Event Listeners & hashchange Reactivity
// ============================================================================
console.log("\n=== SUITE 4: Dynamic Event Listeners & hashchange Reactivity ===");

runTest("hashchange event triggers syncLIFFParameters and updates active tab", () => {
  const { elements, mockWindow } = setupMockEnvironment("", "#tab=dashboard");
  assert(!elements['tab-dashboard'].classList.contains('hidden'));

  // Update hash dynamically
  mockWindow.location.hash = "#tab=calendar&vehicle=pickup";
  mockWindow.dispatchEvent('hashchange');

  assert(elements['tab-dashboard'].classList.contains('hidden'), "dashboard should now be hidden");
  assert(!elements['tab-calendar'].classList.contains('hidden'), "calendar should now be active");
  assert(elements['btn-v-pickup'].className.includes('border-cyan-400'), "pickup should now be highlighted");
  assert(elements['badge-vehicle'].innerHTML.includes("กระบะ"), "badge should be updated to pickup");
});

runTest("hashchange with focus=hazard forces dashboard and triggers pulse animation", () => {
  const { elements, mockWindow } = setupMockEnvironment("", "#tab=calendar");
  assert(!elements['tab-calendar'].classList.contains('hidden'));

  // Change hash to focus hazard
  mockWindow.location.hash = "#tab=calendar&focus=hazard";
  mockWindow.dispatchEvent('hashchange');

  // Hazard focus forces dashboard active
  assert(!elements['tab-dashboard'].classList.contains('hidden'), "hazard focus should force dashboard tab");
  assert(elements['tab-calendar'].classList.contains('hidden'), "calendar tab should be hidden");
  assert(elements['card-hazard'].scrollIntoViewCalled, "card-hazard should be scrolled into view");
  assert(elements['card-hazard'].classList.contains('hazard-pulse-highlight'), "pulse animation class should be added");
});

// ============================================================================
// SUITE 5: #card-hazard Scroll & Apple Spatial Pulse Ring Lifecycle
// ============================================================================
console.log("\n=== SUITE 5: #card-hazard Scroll & Apple Spatial Pulse Ring Lifecycle ===");

runTest("focus=hazard scrolls card-hazard with smooth behavior and center block", () => {
  const { elements } = setupMockEnvironment("?tab=dashboard&focus=hazard", "");
  const card = elements['card-hazard'];
  assert(card.scrollIntoViewCalled, "scrollIntoView must be called");
  assert.strictEqual(card.scrollIntoViewOptions.behavior, 'smooth', "smooth scroll behavior required");
  assert.strictEqual(card.scrollIntoViewOptions.block, 'center', "center block alignment required");
});

runTest("focus=hazard removes 'hidden' class from card-hazard if previously hidden", () => {
  const { elements, sandbox } = setupMockEnvironment("", "");
  const card = elements['card-hazard'];
  card.classList.add('hidden'); // simulate hidden by scrubber
  assert(card.classList.contains('hidden'));

  // Call sync with focus=hazard
  sandbox.window.location.search = "?focus=hazard";
  sandbox.syncLIFFParameters();

  assert(!card.classList.contains('hidden'), "card-hazard must NOT have hidden class after focus");
  assert(card.scrollIntoViewCalled);
});

runTest("focus=hazard forces DOM layout reflow via card.offsetWidth before adding highlight class", () => {
  const { elements } = setupMockEnvironment("?focus=hazard", "");
  const card = elements['card-hazard'];
  assert(card.reflowCount >= 1, "card.offsetWidth must be accessed to force layout reflow");
  assert(card.classList.contains('hazard-pulse-highlight'));
});

runTest("Pulse ring lifecycle: present at t=0ms, active at t=2500ms, removed at t=5000ms", () => {
  const { elements, timerManager } = setupMockEnvironment("?focus=hazard", "");
  const card = elements['card-hazard'];

  // t = 0
  assert(card.classList.contains('hazard-pulse-highlight'), "highlight class must be active at t=0");

  // t = 2500ms (still active during 3-iteration pulse animation)
  timerManager.advance(2500);
  assert(card.classList.contains('hazard-pulse-highlight'), "highlight class must still be active at t=2500ms");

  // t = 5000ms (timeout clears highlight class)
  timerManager.advance(2500);
  assert(!card.classList.contains('hazard-pulse-highlight'), "highlight class must be cleaned up at t=5000ms");
});

runTest("Unrelated focus parameter '?focus=weather' does NOT trigger hazard scroll or highlight", () => {
  const { elements } = setupMockEnvironment("?focus=weather", "");
  const card = elements['card-hazard'];
  assert(!card.scrollIntoViewCalled, "scrollIntoView must NOT be called for focus=weather");
  assert(!card.classList.contains('hazard-pulse-highlight'), "pulse class must NOT be added");
});

runTest("Non-existent card-hazard DOM element does not cause null pointer exception", () => {
  const { mockDocument, sandbox } = setupMockEnvironment("", "");
  // Override getElementById to return null for card-hazard
  const origGet = mockDocument.getElementById;
  mockDocument.getElementById = (id) => (id === 'card-hazard' ? null : origGet(id));

  sandbox.window.location.search = "?focus=hazard";
  // Must execute cleanly without unhandled null dereference
  sandbox.syncLIFFParameters();
});

// ============================================================================
// SUITE 6: HTML & CSS Contract Verification
// ============================================================================
console.log("\n=== SUITE 6: HTML & CSS Contract Verification ===");

runTest("index.html defines @keyframes pulseRing with Theme 1 Apple Spatial styling", () => {
  assert(htmlContent.includes("@keyframes pulseRing"), "Missing @keyframes pulseRing");
  assert(htmlContent.includes("rgba(244, 63, 94,"), "Missing Apple Spatial rose hazard color rgba(244, 63, 94)");
  assert(htmlContent.includes("box-shadow: 0 0 0 14px"), "Missing expanding pulse ring keyframe shadow");
});

runTest("index.html defines .hazard-pulse-highlight class with 1.8s 3-iteration animation", () => {
  assert(htmlContent.includes(".hazard-pulse-highlight"), "Missing .hazard-pulse-highlight class");
  assert(htmlContent.includes("animation: pulseRing 1.8s cubic-bezier(0.4, 0, 0.6, 1) 3"), "Incorrect pulseRing animation spec");
  assert(htmlContent.includes("border: 2px solid rgba(244, 63, 94,"), "Missing rose highlight border");
});

runTest("All 12 required contract DOM element IDs exist in index.html", () => {
  const requiredIds = [
    'tab-dashboard',
    'tab-calendar',
    'tab-profile',
    'nav-dashboard',
    'nav-calendar',
    'nav-profile',
    'btn-v-sedan',
    'btn-v-moto',
    'btn-v-pickup',
    'btn-v-transit',
    'badge-vehicle',
    'card-hazard',
  ];
  for (const id of requiredIds) {
    assert(htmlContent.includes(`id="${id}"`), `Missing required DOM element id="${id}" in index.html`);
  }
});

runTest("JavaScript event hooks window.addEventListener('hashchange', syncLIFFParameters) present", () => {
  assert(htmlContent.includes("window.addEventListener('hashchange', syncLIFFParameters)"),
    "Missing hashchange event registration");
  assert(htmlContent.includes("document.addEventListener('DOMContentLoaded', syncLIFFParameters)"),
    "Missing DOMContentLoaded registration");
});

console.log("\n============================================================================");
console.log(` EMPIRICAL VERIFICATION COMPLETE: ${passedTests}/${totalTests} TESTS PASSED (100%) `);
console.log("============================================================================");
