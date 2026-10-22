export class GatewayError extends Error {
  constructor(code, message, status = 502) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export function identifier(value, label = 'id') {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(value)) {
    throw new GatewayError('invalid_request', `Invalid ${label}.`, 400);
  }
  return value;
}

export function ticks(value = 0) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new GatewayError('invalid_request', 'Ticks must be a nonnegative safe integer.', 400);
  }
  return value;
}
