namespace Company.Function.Models
{
    public record OrderPayload(string Name, double TotalCost, int Quantity = 1);
    public record InventoryRequest(string RequestId, string ItemName, int Quantity);
    public record InventoryResult(bool Success, OrderPayload orderPayload);
    public record PaymentRequest(string RequestId, string ItemBeingPurchased, int Amount, double Currency);
    public record OrderResult(bool Processed);
    public record InventoryItem(string Name, double TotalCost, int Quantity);
    public record Notification(string Message);
}