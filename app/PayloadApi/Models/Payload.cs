namespace PayloadApi.Models;

public class Payload
{
    public int Id { get; set; }
    public string? Content { get; set; }
    public DateTime ReceivedAt { get; set; }
}
