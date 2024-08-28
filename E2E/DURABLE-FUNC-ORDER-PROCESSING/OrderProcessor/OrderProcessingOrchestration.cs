using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.DurableTask;
using Microsoft.DurableTask.Client;
using Microsoft.Extensions.Logging;
using Company.Function.Models;
using Company.Function.Activities;


namespace Company.Function
{
    public static class OrderProcessingOrchestration
    {
        [Function(nameof(OrderProcessingOrchestration))]
        public static async Task<OrderResult> RunOrchestrator(
            [OrchestrationTrigger] TaskOrchestrationContext context, OrderPayload order)
        {
            ILogger logger = context.CreateReplaySafeLogger(nameof(OrderProcessingOrchestration));
          
            // Determine if there is enough of the item available for purchase by checking the inventory
            string orderId = context.InstanceId;
            logger.LogInformation("Started processing order ", orderId);
            InventoryResult result = await context.CallActivityAsync<InventoryResult>(
                nameof(Activities.ReserveInventory), 
                new InventoryRequest(RequestId: orderId, order.Name, order.Quantity));
            
            // If there is insufficient inventory, fail and let the customer know 
            if (!result.Success)
            {
                await context.CallActivityAsync(
                    nameof(Activities.NotifyCustomer), 
                    new Notification($"Insufficient inventory for {order.Name}"));
                return new OrderResult(Processed: false);
            }

            // There is enough inventory available so the user can purchase the item(s). Process their payment
            await context.CallActivityAsync(
                nameof(Activities.ProcessPayment), 
                new PaymentRequest(RequestId: orderId, order.Name, order.Quantity, order.TotalCost));

             try
            {
                // Update inventory 
                await context.CallActivityAsync(
                    nameof(Activities.UpdateInventory), 
                    new PaymentRequest(RequestId: orderId, order.Name, order.Quantity, order.TotalCost));                
            }
            catch (TaskFailedException)
            {
                // Failed to place order. Let customer know they are getting a refund
                await context.CallActivityAsync(
                    nameof(Activities.NotifyCustomer), 
                    new Notification($"Order {orderId} Failed! You are now getting a refund"));
                return new OrderResult(Processed: false);
            }

            // Order has been placed successfully. Notify the customer. 
            await context.CallActivityAsync(
                nameof(Activities.NotifyCustomer), 
                new Notification($"Order {orderId} has completed!"));

    
            return new OrderResult(Processed: true);
        }

        [Function("OrderProcessingOrchestration_HttpStart")]
        public static async Task<HttpResponseData> HttpStart(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequestData req,
            [DurableClient] DurableTaskClient client,
            FunctionContext executionContext)
        {
            ILogger logger = executionContext.GetLogger("OrderProcessingOrchestration_HttpStart");

            // Mimic a new order being placed to start order processing orchestration
            string instanceId = await client.ScheduleNewOrchestrationInstanceAsync(
                nameof(OrderProcessingOrchestration), new OrderPayload("milk", TotalCost: 5, Quantity: 1));

            logger.LogInformation("Started orchestration with ID = '{instanceId}'.", instanceId);

            return await client.CreateCheckStatusResponseAsync(req, instanceId);
        }
    }
}
