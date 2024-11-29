package e2e

import (
	"k8s.io/apimachinery/pkg/runtime/schema"
)

const PolicyTemplate = `{
    "apiVersion": "policy.open-cluster-management.io/v1",
    "kind": "Policy",
    "metadata": {
        "annotations": {
            "policy.open-cluster-management.io/categories": "PR.PT Protective Technology",
            "policy.open-cluster-management.io/controls": "PR.PT-3 Least Functionality",
            "policy.open-cluster-management.io/standards": "NIST-CSF"
        },
        "name": "test-pod-policy",
        "namespace": "open-cluster-management-global-set"
    },
    "spec": {
        "disabled": false,
        "policy-templates": [
            {
                "objectDefinition": {
                    "apiVersion": "policy.open-cluster-management.io/v1",
                    "kind": "ConfigurationPolicy",
                    "metadata": {
                        "name": "test-pod-policy-nginx-pod"
                    },
                    "spec": {
                        "namespaceSelector": {
                            "exclude": [
                                "kube-*"
                            ],
                            "include": [
                                "default"
                            ]
                        },
                        "object-templates": [
                            {
                                "complianceType": "musthave",
                                "objectDefinition": {
                                    "apiVersion": "v1",
                                    "kind": "Pod",
                                    "metadata": {
                                        "name": "nginx-pod-test"
                                    },
                                    "spec": {
                                        "containers": [
                                            {
                                                "image": "nginx:1.18.0",
                                                "name": "nginx",
                                                "ports": [
                                                    {
                                                        "containerPort": 80
                                                    }
                                                ]
                                            }
                                        ]
                                    }
                                }
                            }
                        ],
                        "remediationAction": "inform",
                        "severity": "low"
                    }
                }
            }
        ],
        "remediationAction": "inform"
    }
}`

const PlacementBindingTemplate = `{
    "apiVersion": "policy.open-cluster-management.io/v1",
    "kind": "PlacementBinding",
    "metadata": {
        "name": "test-placementbinding",
        "namespace": "open-cluster-management-global-set"
    },
    "placementRef": {
        "apiGroup": "cluster.open-cluster-management.io",
        "kind": "Placement",
        "name": "global"
    },
    "subjects": [
        {
            "apiGroup": "policy.open-cluster-management.io",
            "kind": "Policy",
            "name": "test-pod-policy"
        }
    ]
}`

var (
	PolicyGVR           = schema.GroupVersionResource{Group: "policy.open-cluster-management.io", Version: "v1", Resource: "policies"}
	PlacementBindingGVR = schema.GroupVersionResource{Group: "policy.open-cluster-management.io", Version: "v1", Resource: "placementbindings"}
)
