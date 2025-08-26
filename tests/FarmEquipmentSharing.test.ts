import { describe, it, expect } from "vitest";
import { simnet } from "clarigen/test";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;

describe("FarmEquipmentSharing contract", () => {
  it("registers equipment and retrieves it", () => {
    // Register equipment
    const { result: regResult } = simnet.callPublicFn(
      "FarmEquipmentSharing",
      "register-equipment",
      [
        '"Tractor"',
        '"Heavy Machinery"',
        "u100",
        "u500",
        '"Field 1, Village X"'
      ],
      address1
    );
    expect(regResult.type).toBe("ok");

    // Retrieve equipment
    const { result: eqResult } = simnet.callReadOnlyFn(
      "FarmEquipmentSharing",
      "get-equipment",
      ["u1"],
      address1
    );
    expect(eqResult.type).toBe("some");
  });
});