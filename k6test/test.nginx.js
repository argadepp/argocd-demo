import http from 'k6/http';
import { sleep } from 'k6';

export default function () {
  let response = http.get('http://nginx.localhost');
  console.log(`Response time: ${response.timings.duration}ms`);
  sleep(1);
}
