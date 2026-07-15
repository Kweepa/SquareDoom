/**
 * Verify Judd/Arndt square tables + TheKeep mid-product vs (aux*fac)>>8.
 */
function buildTabs() {
  const T = new Uint8Array(0x800);
  const S1 = 0,
    S2 = 0x200,
    S3 = 0x400,
    S4 = 0x600;
  T[S3 + 0xfe] = 0;
  T[S4 + 0xfe] = 0;
  let y = 0xff;
  for (let x = 0; x < 256; x++) {
    let al = (x >> 1) + T[S3 + 0xfe + x];
    const c1 = al > 255 ? 1 : 0;
    al &= 255;
    T[S1 + x] = al;
    T[S3 + 0xff + x] = al;
    T[S3 + y] = al;
    let ah = c1 + T[S4 + 0xfe + x];
    ah &= 255;
    T[S2 + x] = ah;
    T[S4 + 0xff + x] = ah;
    T[S4 + y] = ah;
    y = (y - 1) & 0xff;
  }
  for (let x = 0; x < 256; x++) {
    // SEC; ROR A with A=x → (x>>1)|0x80, C=x&1; then CLC; ADC
    let a = ((x >> 1) | 0x80) & 0xff;
    let sum = a + T[S1 + 0xff + x];
    const c = sum > 255 ? 1 : 0;
    T[S1 + 0x100 + x] = sum & 255;
    T[S2 + 0x100 + x] = (c + T[S2 + 0xff + x]) & 255;
  }
  return T;
}

function mul8x8(T, fa, fb) {
  const S1 = 0,
    S2 = 0x200,
    S3 = 0x400,
    S4 = 0x600;
  const a = fb & 0xff;
  const y = fa & 0xff;
  const read = (base, lo, y) => T[base + lo + y];
  const slo = read(S1, a, y);
  const clo = read(S3, a ^ 0xff, y);
  const shi = read(S2, a, y);
  const chi = read(S4, a ^ 0xff, y);
  let lo = (slo - clo) & 0xff;
  const borrow = slo < clo ? 1 : 0;
  let hi = (shi - chi - borrow) & 0xff;
  return lo | (hi << 8);
}

function mid16(T, aux, fac) {
  const loProd = mul8x8(T, fac, aux & 0xff);
  const hiProd = mul8x8(T, fac, (aux >> 8) & 0xff);
  return (((loProd >> 8) & 0xff) + hiProd) & 0xffff;
}

const T = buildTabs();
let bad = 0;
for (let a = 0; a < 256; a++) {
  for (let b = 0; b < 256; b++) {
    const got = mul8x8(T, a, b);
    const want = (a * b) & 0xffff;
    if (got !== want) {
      if (bad < 8) console.log('8x8', a, b, got.toString(16), want.toString(16));
      bad++;
    }
  }
}
console.log('8x8 mismatches', bad);

bad = 0;
const auxes = [0, 1, 0xff, 0x100, 0x1234, 0xabcd, 0xffff, 0x500, 0x80, 0x200];
for (const aux of auxes) {
  for (let f = 0; f < 256; f++) {
    const got = mid16(T, aux, f);
    const want = ((aux * f) >> 8) & 0xffff;
    if (got !== want) {
      if (bad < 8) console.log('mid', aux, f, got.toString(16), want.toString(16));
      bad++;
    }
  }
}
console.log('mid mismatches', bad);
