package spec_test

import (
	"os"
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
)

var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))

	// The blueprint hook lists deployments through the bosh CLI, so put a
	// stand-in ahead of any real binary on the PATH.
	stubDir := filepath.Join(filepath.Dir(filename), "bin")
	// A proxy setting makes genesis skip its raw TCP probe of the director
	// and ask the stand-in instead.
	os.Setenv("BOSH_ALL_PROXY", "socks5://127.0.0.1:1")
	os.Setenv("PATH", stubDir+string(os.PathListSeparator)+os.Getenv("PATH"))
})

var _ = Describe("Doomsday Kit", func() {

	Describe("Doomdsay", func() {
		Test(Environment{
			Name:        "base",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "base-all-params",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "base-stackit",
			CloudConfig: "stackit",
			CPI:         "stackit",
		})
		Test(Environment{
			Name:        "base-stackit-all-params",
			CloudConfig: "stackit",
			CPI:         "stackit",
		})
	})
})
