import http from 'k6/http';
import { sleep, check } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics
const loginTrend = new Trend('login_duration');
const orderTrend = new Trend('order_duration');
const errorRate = new Rate('errors');
const requests = new Counter('total_requests');

export let options = {
  stages: [
    { duration: '1m', target: 10 }, // Ramp-up to 10 VUs
    { duration: '3m', target: 50 }, // Stay at 50 VUs
    { duration: '1m', target: 0 }, // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'], // 95% of requests must complete below 500ms
    'errors': ['rate<0.05'], // <5% error rate
  },
};

// Base URL for the application
const BASE_URL = __ENV.BASE_URL || 'http://nginx.localhost';

// Shared headers
const headers = {
  'Content-Type': 'application/json',
};

// Test data
const productIds = [101, 102, 103, 104, 105];

export default function () {
  // Step 1: Login
  const loginPayload = JSON.stringify({ username: 'test_user', password: '123456' });
  const loginRes = http.post(`${BASE_URL}/login`, loginPayload, { headers });

  // Record login metrics and check
  loginTrend.add(loginRes.timings.duration);
  check(loginRes, {
    'login successful': (res) => res.status === 200 && res.json('token') !== undefined,
  }) || errorRate.add(1);

  // Extract token
  const token = loginRes.json('token');
  headers['Authorization'] = `Bearer ${token}`;

  // Step 2: Browse products
  const browseRes = http.get(`${BASE_URL}/products`, { headers });
  check(browseRes, { 'browse successful': (res) => res.status === 200 }) || errorRate.add(1);
  sleep(1);

  // Step 3: Place an order
  const orderPayload = JSON.stringify({
    productId: productIds[Math.floor(Math.random() * productIds.length)],
    quantity: Math.floor(Math.random() * 3) + 1,
  });
  const orderRes = http.post(`${BASE_URL}/order`, orderPayload, { headers });

  // Record order metrics and check
  orderTrend.add(orderRes.timings.duration);
  check(orderRes, { 'order successful': (res) => res.status === 201 }) || errorRate.add(1);

  // Increment total request counter
  requests.add(1);

  sleep(2); // Simulate user think time
}
