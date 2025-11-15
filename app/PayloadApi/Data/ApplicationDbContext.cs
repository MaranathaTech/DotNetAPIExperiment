using Microsoft.EntityFrameworkCore;
using PayloadApi.Models;

namespace PayloadApi.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Payload> Payloads { get; set; }
}
