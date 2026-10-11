package routerbox

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestDNSByTrafficDirection(t *testing.T) {
	s := Defaults()
	s.DirectDNS = "quad9"
	s.VPNDNS = "cloudflare"
	s.Subscriptions = []Subscription{{ID: "sub", URL: "https://example.com/sub", Enabled: true, Interval: 24}}
	nodes := []Node{{ID: "node", Subscription: "sub", Config: Object{"type": "socks", "server": "127.0.0.1", "server_port": 1080}}}
	s.Rules = []Rule{
		{ID: "direct", Name: "direct", Enabled: true, Target: "direct", Domains: []string{"*.example.ru"}},
		{ID: "vpn", Name: "vpn", Enabled: true, Target: "vpn", Domains: []string{"*.example.com"}},
		{ID: "override", Name: "override", Enabled: true, Target: "vpn", Domains: []string{"example.net"}, DNS: "quad9"},
		{ID: "device", Name: "device", Enabled: true, Target: "vpn", Domains: []string{"example.org"}, Sources: []string{"192.168.1.2"}},
	}
	for _, final := range []string{"direct", "vpn"} {
		s.Final = final
		config, err := Generate(s, nodes, nil, t.TempDir(), "test", true)
		if err != nil {
			t.Fatal(err)
		}
		dns := config["dns"].(Object)
		want := "quad9"
		if final == "vpn" {
			want = "cloudflare"
		}
		if dns["final"] != want {
			t.Fatalf("final %s: %v", final, dns["final"])
		}
		rules := dns["rules"].([]Object)
		if len(rules) != 5 {
			t.Fatalf("device-scoped DNS rule must not be generated: %v", rules)
		}
		for i, server := range []string{"quad9", "cloudflare", "quad9"} {
			if rules[i+2]["server"] != server {
				t.Fatalf("rule %d: %v", i, rules[i+2])
			}
		}
		if core := os.Getenv("ROUTERBOX_TEST_CORE"); core != "" {
			path := filepath.Join(t.TempDir(), "config.json")
			if err := writeJSON(path, config); err != nil {
				t.Fatal(err)
			}
			if b, err := exec.Command(core, "check", "-c", path).CombinedOutput(); err != nil {
				t.Fatalf("core check: %s %v", b, err)
			}
		}
	}
	s.DirectDNS = "missing"
	if _, err := Generate(s, nodes, nil, t.TempDir(), "test", true); err == nil {
		t.Fatal("deleted DNS accepted")
	}
	s = Defaults()
	config, err := Generate(s, nil, nil, t.TempDir(), "test", true)
	if err != nil {
		t.Fatal(err)
	}
	if config["dns"].(Object)["final"] != "dns-default" {
		t.Fatal("legacy default changed")
	}
}
