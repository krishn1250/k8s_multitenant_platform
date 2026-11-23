// k6 load test: steady mixed traffic against one tenant through the Gateway.
// Run: make load   (Gateway port-forwarded to localhost:8080)
import http from 'k6/http';
import { check, sleep } from 'k6';

const TENANT = __ENV.TENANT || 'team-a';
const BASE = __ENV.BASE_URL || 'http://localhost:8080';
const params = { headers: { Host: `${TENANT}.orders.local`, 'Content-Type': 'application/json' } };

export const options = {
  scenarios: {
    steady: { executor: 'constant-arrival-rate', rate: 20, timeUnit: '1s', duration: '10m', preAllocatedVUs: 20 },
  },
  // Mirrors the SLOs: the test itself fails if we would breach them.
  thresholds: {
    http_req_failed: ['rate<0.005'],
    http_req_duration: ['p(99)<300'],
  },
};

export default function () {
  if (Math.random() < 0.3) {
    const r = http.post(`${BASE}/orders`, JSON.stringify({ item: 'coffee', quantity: 1 }), params);
    check(r, { 'created 201': (res) => res.status === 201 });
  } else {
    const r = http.get(`${BASE}/orders?limit=10`, params);
    check(r, { 'list 200': (res) => res.status === 200 });
  }
  sleep(0.1);
}
