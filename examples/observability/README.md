# Observability Examples

This directory contains examples for using the observability components in the cluster.

## Tempo Tracing Example

The `tempo-tracing-example.yaml` file demonstrates how to instrument a simple application to send traces to Tempo.

### Prerequisites

- Tempo must be deployed in the cluster
- Grafana must be deployed and configured with Tempo as a datasource

### Deployment

To deploy the example:

```bash
kubectl apply -f examples/observability/tempo-tracing-example.yaml
```

This will deploy:
1. A simple Flask application instrumented with OpenTelemetry to send traces to Tempo
2. A service to expose the application
3. A job that generates traffic to the application

### Viewing Traces

1. Port-forward Grafana:
   ```bash
   kubectl port-forward -n observability svc/prometheus-stack-grafana 3000:80
   ```

2. Open Grafana in your browser: http://localhost:3000 (default credentials: admin/admin)

3. Navigate to Explore and select Tempo as the datasource

4. You can search for traces by:
   - Service name: `tracing-demo-service`
   - Operation name: `hello` or `database_query`
   - Duration: Filter for traces that took longer than a certain time
   - Status: Filter for traces with errors

### Understanding the Example

The example application:
- Uses OpenTelemetry to instrument a simple Flask application
- Creates spans for HTTP requests and simulated database calls
- Adds attributes to spans (HTTP method, URL, database system, operation)
- Randomly introduces errors in the database calls
- Sends traces to Tempo using the OTLP protocol

This demonstrates the basic concepts of distributed tracing:
- Creating spans for different operations
- Nesting spans to show the relationship between operations
- Adding attributes to spans for context
- Recording errors and exceptions
- Exporting traces to a tracing backend (Tempo)

### Cleanup

To remove the example:

```bash
kubectl delete -f examples/observability/tempo-tracing-example.yaml
``` 