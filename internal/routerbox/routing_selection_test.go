package routerbox

import (
	"reflect"
	"testing"
)

func TestSaveRemovesDeletedOrDisabledSubscriptionSelections(t *testing.T) {
	for _, disabled := range []bool{false, true} {
		s := Defaults()
		s.Subscriptions = []Subscription{{ID: "keep", Enabled: true}}
		if disabled {
			s.Subscriptions = append(s.Subscriptions, Subscription{ID: "remove", Enabled: false})
		}
		s.Final = "vpn"
		s.FinalNodes = []string{"gone", "remaining"}
		s.FinalMode = "manual"
		s.FinalSelected = "gone"
		s.Rules = []Rule{{ID: "vpn", Name: "vpn", Enabled: true, Target: "vpn", Nodes: []string{"gone", "remaining"}, Mode: "stable", SeparateUDP: true, UDPNodes: []string{"gone"}, UDPMode: "manual", UDPSelected: "gone"}}
		nodes := []Node{{ID: "gone", Subscription: "remove"}, {ID: "remaining", Subscription: "keep"}}
		removeDisabledSubscriptionSelections(&s, nodes)
		if !reflect.DeepEqual(s.FinalNodes, []string{"remaining"}) || s.FinalSelected != "" || s.FinalMode != "stable" || len(s.Rules[0].UDPNodes) != 0 || s.Rules[0].UDPMode != "stable" {
			t.Fatalf("stale selection remains: %+v", s)
		}
		resolved, err := resolveRouting(s, nodes)
		if err != nil {
			t.Fatal(err)
		}
		for _, g := range resolved.Groups {
			if !reflect.DeepEqual(g.Nodes, []string{"remaining"}) {
				t.Fatalf("deleted server retained: %+v", g)
			}
		}
	}
}

func TestRemovalDoesNotHideUnrelatedInvalidServer(t *testing.T) {
	s := Defaults()
	s.Subscriptions = []Subscription{{ID: "keep", Enabled: true}}
	s.Final = "vpn"
	s.FinalNodes = []string{"unknown"}
	nodes := []Node{{ID: "remaining", Subscription: "keep"}}
	removeDisabledSubscriptionSelections(&s, nodes)
	if _, err := resolveRouting(s, nodes); err == nil {
		t.Fatal("unrelated invalid server accepted")
	}
}
