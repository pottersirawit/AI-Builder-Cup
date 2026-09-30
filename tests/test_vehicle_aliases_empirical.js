#!/usr/bin/env node
/**
 * Bangkok Weather Resilience & Disaster Preparedness System
 * Empirical Challenger Verification Suite: Vehicle Aliases & LIFF Parameter Synchronization
 * 
 * Verifies Requirement 2:
 * 1. Mandatory Test URLs:
 *    - ?vehicle=motorcycle    -> activates btn-v-moto, badge: '🛵 มอเตอร์ไซค์'
 *    - ?vehicle=moto          -> activates btn-v-moto, badge: '🛵 มอเตอร์ไซค์'
 *    - ?vehicle=compact_sedan -> activates btn-v-sedan, badge: '🚗 รถเก๋งเตี้ย'
 *    - ?vehicle=sedan         -> activates btn-v-sedan, badge: '🚗 รถเก๋งเตี้ย'
 *    - ?vehicle=suv           -> activates btn-v-pickup, badge: '🚙 กระบะ / SUV'
 *    - ?vehicle=pickup        -> activates btn-v-pickup, badge: '🚙 กระบะ / SUV'
 *    - ?vehicle=bts           -> activates btn-v-transit, badge: '🚆 รถไฟฟ้า'
 *    - ?vehicle=mrt           -> activates btn-v-transit, badge: '🚆 รถไฟฟ้า'
 *    - ?vehicle=transit       -> activates btn-v-transit, badge: '🚆 รถไฟฟ้า'
 * 2. Ensure none fall back to incorrect defaults and all activate correct UI buttons.
 * 3. Challenge alias variants in liff.state, hash fragments, and direct JS API.
 * 4. Surface case-sensitivity boundary behavior for canonical keys.
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const htmlPath = path.resolve(__dirname, '../gateway/static/liff/index.html');
assert(fs.existsSync(htmlPath), `Static LIFF file not found at ${htmlPath}`);
const htmlContent = fs.readFileSync(htmlPath, 'utf8');

const scriptMatch = htmlContent.match(/<script>([\s\S]*?)<\/script>/);
assert(scriptMatch, "Failed to find <script> in index.html");
const jsCode = scriptMatch[1];

function createMockElement(id, initialClasses = '') {
  let classes = initialClasses.split(/\s+/).filter(Boolean);
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
    offsetWidth: 100,
    scrollIntoViewCalled: false,
    scrollIntoViewOptions: null,
    scrollIntoView: function(opts) {
      this.scrollIntoViewCalled = true;
      this.scrollIntoViewOptions = opts;
    },
    style: {}
  };
}

function runVehicleTest(name, { search = '', hash = '', directCall = null }) {
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

  const mockWindow = {
    location: {
      search: search || '',
      hash: hash || '',
    },
    addEventListener: () => {},
  };

  const mockDocument = {
    readyState: 'complete',
    getElementById: (id) => elements[id] || null,
    addEventListener: () => {},
  };

  const sandbox = {
    window: mockWindow,
    document: mockDocument,
    console: { log: () => {}, warn: () => {}, error: () => {} },
    URLSearchParams: URLSearchParams,
    decodeURIComponent: decodeURIComponent,
    setTimeout: (fn) => fn(),
  };

  vm.createContext(sandbox);
  vm.runInContext(jsCode, sandbox);

  if (directCall) {
    sandbox[directCall.func](...directCall.args);
  }

  return elements;
}

const VEHICLE_SPECS = {
  moto: {
    btnId: 'btn-v-moto',
    badgeText: '🛵 มอเตอร์ไซค์',
  },
  sedan: {
    btnId: 'btn-v-sedan',
    badgeText: '🚗 รถเก๋งเตี้ย',
  },
  pickup: {
    btnId: 'btn-v-pickup',
    badgeText: '🚙 กระบะ / SUV',
  },
  transit: {
    btnId: 'btn-v-transit',
    badgeText: '🚆 รถไฟฟ้า',
  },
};

function verifyVehicleState(name, elements, expectedVehicleKey) {
  const spec = VEHICLE_SPECS[expectedVehicleKey];
  assert(spec, `Unknown vehicle key: ${expectedVehicleKey}`);

  const activeBtn = elements[spec.btnId];
  assert(activeBtn, `Active button element not found: ${spec.btnId}`);
  assert(
    activeBtn.className.includes('border-cyan-400') && activeBtn.className.includes('bg-cyan-500/20'),
    `[${name}] Expected ${spec.btnId} to be active (border-cyan-400 bg-cyan-500/20), got: "${activeBtn.className}"`
  );

  // Verify other 3 buttons are NOT active
  for (const [key, otherSpec] of Object.entries(VEHICLE_SPECS)) {
    if (key !== expectedVehicleKey) {
      const otherBtn = elements[otherSpec.btnId];
      assert(
        !otherBtn.className.includes('border-cyan-400'),
        `[${name}] Expected inactive button ${otherSpec.btnId} to NOT have border-cyan-400, got: "${otherBtn.className}"`
      );
      assert(
        otherBtn.className.includes('apple-glass-subtle'),
        `[${name}] Expected inactive button ${otherSpec.btnId} to have apple-glass-subtle, got: "${otherBtn.className}"`
      );
    }
  }

  // Verify badge text
  const badge = elements['badge-vehicle'];
  assert(
    badge.innerHTML.includes(spec.badgeText),
    `[${name}] Expected badge to contain "${spec.badgeText}", got: "${badge.innerHTML}"`
  );

  console.log(`  [PASS] ${name} -> ${spec.btnId} active, badge: "${spec.badgeText}"`);
}

console.log("============================================================================");
console.log(" EMPIRICAL CHALLENGER: VEHICLE ALIASES & LIFF SYNC STRESS TEST");
console.log("============================================================================\n");

let passedCount = 0;

console.log("=== Part 1: Mandatory URL Search Parameter Queries ===");
const mandatoryUrls = [
  { url: "?vehicle=motorcycle", expected: "moto", desc: "motorcycle -> moto" },
  { url: "?vehicle=moto", expected: "moto", desc: "canonical moto" },
  { url: "?vehicle=compact_sedan", expected: "sedan", desc: "compact_sedan -> sedan" },
  { url: "?vehicle=sedan", expected: "sedan", desc: "canonical sedan" },
  { url: "?vehicle=suv", expected: "pickup", desc: "suv -> pickup" },
  { url: "?vehicle=pickup", expected: "pickup", desc: "canonical pickup" },
  { url: "?vehicle=bts", expected: "transit", desc: "bts -> transit" },
  { url: "?vehicle=mrt", expected: "transit", desc: "mrt -> transit" },
  { url: "?vehicle=transit", expected: "transit", desc: "canonical transit" },
];

mandatoryUrls.forEach(({ url, expected, desc }) => {
  const elements = runVehicleTest(`URL ${url} (${desc})`, { search: url });
  verifyVehicleState(`Mandatory URL ${url}`, elements, expected);
  passedCount++;
});

console.log("\n=== Part 2: Alias Case-Insensitivity & Mixed-Case Stress ===");
const aliasCaseUrls = [
  { url: "?vehicle=MOTORCYCLE", expected: "moto", desc: "All-caps MOTORCYCLE" },
  { url: "?vehicle=MotorCycle", expected: "moto", desc: "Mixed-case MotorCycle" },
  { url: "?vehicle=COMPACT_SEDAN", expected: "sedan", desc: "All-caps COMPACT_SEDAN" },
  { url: "?vehicle=Compact_Sedan", expected: "sedan", desc: "Mixed-case Compact_Sedan" },
  { url: "?vehicle=SUV", expected: "pickup", desc: "All-caps SUV" },
  { url: "?vehicle=Suv", expected: "pickup", desc: "Title-case Suv" },
  { url: "?vehicle=BTS", expected: "transit", desc: "All-caps BTS" },
  { url: "?vehicle=Bts", expected: "transit", desc: "Title-case Bts" },
  { url: "?vehicle=MRT", expected: "transit", desc: "All-caps MRT" },
  { url: "?vehicle=Mrt", expected: "transit", desc: "Title-case Mrt" },
];

aliasCaseUrls.forEach(({ url, expected, desc }) => {
  const elements = runVehicleTest(`Alias Case ${url} (${desc})`, { search: url });
  verifyVehicleState(`Alias Case ${url}`, elements, expected);
  passedCount++;
});

console.log("\n=== Part 3: Nested in liff.state Parameter ===");
const liffStateUrls = [
  { url: "?liff.state=%3Fvehicle%3Dmotorcycle", expected: "moto" },
  { url: "?liff.state=%3Fvehicle%3Dmoto", expected: "moto" },
  { url: "?liff.state=%3Fvehicle%3Dcompact_sedan", expected: "sedan" },
  { url: "?liff.state=%3Fvehicle%3Dsedan", expected: "sedan" },
  { url: "?liff.state=%3Fvehicle%3Dsuv", expected: "pickup" },
  { url: "?liff.state=%3Fvehicle%3Dpickup", expected: "pickup" },
  { url: "?liff.state=%3Fvehicle%3Dbts", expected: "transit" },
  { url: "?liff.state=%3Fvehicle%3Dmrt", expected: "transit" },
  { url: "?liff.state=%3Fvehicle%3Dtransit", expected: "transit" },
  { url: "?liff.state=%2Fliff%3Ftab%3Dprofile%26vehicle%3DMOTORCYCLE", expected: "moto" },
  { url: "?liff.state=%2Fliff%3Ftab%3Dprofile%26vehicle%3DSUV", expected: "pickup" },
  { url: "?liff.state=%2Fliff%3Ftab%3Dcalendar%26vehicle%3DBTS", expected: "transit" },
];

liffStateUrls.forEach(({ url, expected }) => {
  const elements = runVehicleTest(`liff.state: ${url}`, { search: url });
  verifyVehicleState(`liff.state: ${url}`, elements, expected);
  passedCount++;
});

console.log("\n=== Part 4: URL Hash Routing ===");
const hashUrls = [
  { hash: "#vehicle=motorcycle", expected: "moto" },
  { hash: "#vehicle=moto", expected: "moto" },
  { hash: "#vehicle=compact_sedan", expected: "sedan" },
  { hash: "#vehicle=sedan", expected: "sedan" },
  { hash: "#vehicle=suv", expected: "pickup" },
  { hash: "#vehicle=pickup", expected: "pickup" },
  { hash: "#vehicle=bts", expected: "transit" },
  { hash: "#vehicle=mrt", expected: "transit" },
  { hash: "#vehicle=transit", expected: "transit" },
  { hash: "#/view?vehicle=motorcycle", expected: "moto" },
  { hash: "#/view?tab=profile&vehicle=suv", expected: "pickup" },
  { hash: "#liff.state=%3Fvehicle%3Dmotorcycle", expected: "moto" },
];

hashUrls.forEach(({ hash, expected }) => {
  const elements = runVehicleTest(`Hash: ${hash}`, { hash });
  verifyVehicleState(`Hash: ${hash}`, elements, expected);
  passedCount++;
});

console.log("\n=== Part 5: Direct Javascript setVehicle() Function Invocations ===");
const directCalls = [
  { arg: 'motorcycle', expected: 'moto', desc: "direct setVehicle('motorcycle')" },
  { arg: 'MOTORCYCLE', expected: 'moto', desc: "direct setVehicle('MOTORCYCLE')" },
  { arg: 'moto', expected: 'moto', desc: "direct setVehicle('moto')" },
  { arg: 'compact_sedan', expected: 'sedan', desc: "direct setVehicle('compact_sedan')" },
  { arg: 'COMPACT_SEDAN', expected: 'sedan', desc: "direct setVehicle('COMPACT_SEDAN')" },
  { arg: 'sedan', expected: 'sedan', desc: "direct setVehicle('sedan')" },
  { arg: 'suv', expected: 'pickup', desc: "direct setVehicle('suv')" },
  { arg: 'SUV', expected: 'pickup', desc: "direct setVehicle('SUV')" },
  { arg: 'pickup', expected: 'pickup', desc: "direct setVehicle('pickup')" },
  { arg: 'bts', expected: 'transit', desc: "direct setVehicle('bts')" },
  { arg: 'BTS', expected: 'transit', desc: "direct setVehicle('BTS')" },
  { arg: 'mrt', expected: 'transit', desc: "direct setVehicle('mrt')" },
  { arg: 'MRT', expected: 'transit', desc: "direct setVehicle('MRT')" },
  { arg: 'transit', expected: 'transit', desc: "direct setVehicle('transit')" },
  { arg: 'unsupported_spaceship', expected: 'sedan', desc: "defensive fallback for invalid token" },
  { arg: '', expected: 'sedan', desc: "empty string fallback" },
  { arg: null, expected: 'sedan', desc: "null argument fallback" },
];

directCalls.forEach(({ arg, expected, desc }) => {
  const elements = runVehicleTest(desc, {
    directCall: { func: 'setVehicle', args: [arg] }
  });
  verifyVehicleState(desc, elements, expected);
  passedCount++;
});

console.log("\n============================================================================");
console.log(` ALL ${passedCount} EMPIRICAL VEHICLE ALIAS TESTS PASSED (100%)!`);
console.log("============================================================================\n");
