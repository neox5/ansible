#!/usr/bin/env bash
# Quick verification after deployment

echo "=== Monitoring Stack Verification ==="
echo

echo "1. Containers running:"
podman ps --format "{{.Names}}\t{{.Status}}" | grep -E "alloy|victoria|grafana"
echo

echo "2. Alloy health:"
curl -sf http://localhost:12345/ > /dev/null && echo "✓ Alloy responding" || echo "✗ Alloy not responding"
echo

echo "3. VictoriaMetrics health:"
curl -sf 'http://localhost:8428/api/v1/query?query=up' > /dev/null && echo "✓ VictoriaMetrics responding" || echo "✗ VictoriaMetrics not responding"
echo

echo "4. Grafana health:"
curl -sf http://localhost:3000/api/health > /dev/null && echo "✓ Grafana responding" || echo "✗ Grafana not responding"
echo

echo "5. Metrics collected:"
TARGETS=$(curl -s 'http://localhost:8428/api/v1/query?query=up' | jq -r '.data.result | length' 2>/dev/null || echo "0")
echo "   Targets: $TARGETS"
echo

echo "6. n8n metrics:"
curl -sf http://localhost:5678/metrics > /dev/null && echo "✓ n8n metrics available" || echo "✗ n8n metrics not available"
echo

echo "Access:"
echo "  Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "  Login: admin / (see monitoring.env)"
