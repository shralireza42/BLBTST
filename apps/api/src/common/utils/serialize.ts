export function serializeForJson<T>(value: T): T {
  return JSON.parse(
    JSON.stringify(value, (_key, innerValue) => {
      if (typeof innerValue === "bigint") return innerValue.toString();
      if (innerValue && typeof innerValue === "object" && "toString" in innerValue && innerValue.constructor?.name === "Decimal") {
        return innerValue.toString();
      }
      return innerValue;
    })
  ) as T;
}
