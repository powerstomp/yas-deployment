
set -x

# Auto restart when change configmap or secret
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

helm dependency build ../charts/yas-configuration
helm upgrade --install yas-configuration ../charts/yas-configuration \
--namespace yas --create-namespace

# Add *.yas.local.com wildcard entries to CoreDNS hosts plugin.
# This bypasses Java DNS resolver issues with CoreDNS rewrite rules.
# Both IPs are resolved dynamically so the script works on any machine.
TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.spec.clusterIP}')
NODE_IP=$(kubectl get node yas-ops -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
kubectl patch configmap -n kube-system coredns --type=merge \
  -p "{\"data\":{\"NodeHosts\":\"${NODE_IP} yas-ops\n# *.yas.local.com wildcard aliases\n${TRAEFIK_IP} identity.yas.local.com storefront.yas.local.com backoffice.yas.local.com api.yas.local.com pgadmin.yas.local.com akhq.yas.local.com kibana.yas.local.com grafana.yas.local.com kiali.yas.local.com\"}}"
kubectl rollout restart deployment -n kube-system coredns
