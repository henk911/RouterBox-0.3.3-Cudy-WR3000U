package routerbox

import (
	"encoding/json"
	"net/url"
	"os"
	"strings"
	"testing"
)

// A public ECHConfigList for example.com (sing-box generate ech-keypair).
const testECHConfigList = "AEb+DQBCAAAgACD4YTxKv6O6mys8y1CGY0iMtuMLRjWh+TwdbR+TKe3PdAAMAAEAAQABAAIAAQADAAtleGFtcGxlLmNvbQAA"
const testRealityKey = "H0I_8rC9-Kff1No4hANNV6UV1ArejXTUULjpt383BHw"

// Links as 3x-ui / Xray publish them: REALITY with pqv and spx, XHTTP with
// spx, Hysteria2 with ech and fp.
func TestShareLinkXrayExtras(t *testing.T) {
	id := "11111111-1111-4111-8111-111111111111"
	links := []string{
		"vless://" + id + "@example.com:443?type=tcp&security=reality&pbk=" + testRealityKey + "&sid=ab12&sni=www.example.com&fp=chrome&flow=xtls-rprx-vision&spx=%2F&pqv=" + strings.Repeat("A", 64) + "#REALITY",
		"vless://" + id + "@example.com:443?type=xhttp&mode=auto&path=%2Fx&security=reality&pbk=" + testRealityKey + "&sid=ab12&sni=www.example.com&fp=chrome&spx=%2Fspider#XHTTP",
		"hy2://secret@example.com:443?sni=example.com&fp=chrome&ech=" + url.QueryEscape(testECHConfigList) + "#HY2",
		"vless://" + id + "@example.com:443?type=ws&path=%2Fws&security=tls&sni=example.com&fp=chrome&ech=" + url.QueryEscape("cloudflare-ech.com+https://1.1.1.1/dns-query") + "#WS",
	}
	nodes, bad, err := ParseSubscription([]byte(strings.Join(links, "\n")), "sub")
	if err != nil || len(bad) != 0 || len(nodes) != len(links) {
		t.Fatalf("nodes=%d bad=%v err=%v", len(nodes), bad, err)
	}
	byName := map[string]Object{}
	for _, n := range nodes {
		b, _ := json.Marshal(n.Config)
		for _, leak := range []string{"pqv", "spx", "spider"} {
			if strings.Contains(string(b), leak) {
				t.Fatalf("%s: %s leaked into config %s", n.Name, leak, b)
			}
		}
		byName[n.Name] = n.Config
	}
	reality := obj(obj(byName["REALITY"]["tls"])["reality"])
	if str(reality, "public_key") != testRealityKey || str(reality, "short_id") != "ab12" {
		t.Fatal("REALITY key lost", reality)
	}
	hyTLS := obj(byName["HY2"]["tls"])
	if hyTLS["utls"] != nil {
		t.Fatal("uTLS set for a QUIC protocol")
	}
	config, _ := obj(hyTLS["ech"])["config"].([]any) // nodes are JSON copies
	if pemText, _ := firstString(config); !strings.HasPrefix(pemText, "-----BEGIN ECH CONFIGS-----") || len(config) != 1 || obj(hyTLS["ech"])["enabled"] != true {
		t.Fatal("Hysteria2 ECH config not converted", hyTLS["ech"])
	}
	wsTLS := obj(byName["WS"]["tls"])
	if str(obj(wsTLS["ech"]), "query_server_name") != "cloudflare-ech.com" || wsTLS["utls"] == nil {
		t.Fatal("ECH DNS query or uTLS lost", wsTLS)
	}
	if core := os.Getenv("ROUTERBOX_TEST_CORE"); core != "" {
		m, e := NewManager(t.TempDir(), t.TempDir(), core)
		if e != nil {
			t.Fatal(e)
		}
		for _, n := range nodes {
			if e = m.checkNode(n); e != nil {
				t.Fatalf("%s rejected by core: %v", n.Name, e)
			}
		}
	}
}

func firstString(list []any) (string, bool) {
	if len(list) == 0 {
		return "", false
	}
	s, ok := list[0].(string)
	return s, ok
}

func TestShareLinkECHEdgeCases(t *testing.T) {
	id := "11111111-1111-4111-8111-111111111111"
	// REALITY conflicts with ECH in the core: ech is not applied there.
	nodes, bad, _ := ParseSubscription([]byte("vless://"+id+"@example.com:443?security=reality&pbk="+testRealityKey+"&ech="+url.QueryEscape(testECHConfigList)+"#R"), "sub")
	if len(nodes) != 1 || len(bad) != 0 || obj(nodes[0].Config["tls"])["ech"] != nil {
		t.Fatal("ECH applied to REALITY", nodes, bad)
	}
	// An unreadable value is reported instead of silently dropping ECH.
	nodes, bad, _ = ParseSubscription([]byte("trojan://secret@example.com:443?sni=example.com&ech=not*valid#T"), "sub")
	if len(nodes) != 0 || len(bad) != 1 || !strings.Contains(bad[0].Reason, "ech") {
		t.Fatal("invalid ech accepted", nodes, bad)
	}
	// TUIC is QUIC too: no uTLS.
	nodes, _, _ = ParseSubscription([]byte("tuic://"+id+":pw@example.com:443?sni=example.com&fp=chrome&congestion_control=bbr#U"), "sub")
	if len(nodes) != 1 || obj(nodes[0].Config["tls"])["utls"] != nil {
		t.Fatal("uTLS set for TUIC", nodes)
	}
}
