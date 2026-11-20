const { spawnSync } = require("node:child_process");
const path = require("node:path");
const test = require("node:test");

test("Registry test place matches its source tree", () => {
    const python = process.env.REGISTRY_TEST_PYTHON || (process.platform === "win32" ? "python" : "python3");
    const result = spawnSync(python, [path.join(__dirname, "check.py")], { encoding: "utf8" });
    if (result.error || result.status !== 0) {
        throw new Error(result.error?.message || result.stderr?.trim() || `Verifier exited with status ${result.status}`);
    }
});
