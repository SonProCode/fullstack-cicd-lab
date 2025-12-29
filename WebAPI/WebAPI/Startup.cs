using System;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using WebAPI.Models;
using Microsoft.AspNetCore.Http;

namespace WebAPI
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddControllers();

            // ===== READ FROM ECS ENV (TERRAFORM-INJECTED) =====
            var dbHost = Configuration["DB_HOST"];        // từ <RDS-ENDPOINT>
            var dbName = Configuration["DB_NAME"];
            var dbUser = Configuration["DB_USER"];
            var dbPass = Configuration["DB_PASSWORD"];    // từ Secrets Manager

            if (string.IsNullOrWhiteSpace(dbHost) ||
                string.IsNullOrWhiteSpace(dbName) ||
                string.IsNullOrWhiteSpace(dbUser) ||
                string.IsNullOrWhiteSpace(dbPass))
            {
                throw new Exception("Database environment variables are missing");
            }

            var connectionString =
                $"Server={dbHost};Port=3306;Database={dbName};User={dbUser};Password={dbPass};";

            services.AddDbContext<DonationDBContext>(options =>
                options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString)));

            // ===== CORS =====
            services.AddCors(options =>
            {
                options.AddPolicy("FrontendPolicy", builder =>
                {
                    var allowedOrigins = Configuration["CORS_ALLOWED_ORIGINS"];
                    if (!string.IsNullOrEmpty(allowedOrigins))
                    {
                        builder.WithOrigins(
                                allowedOrigins.Split(',', StringSplitOptions.RemoveEmptyEntries)
                            )
                            .AllowAnyHeader()
                            .AllowAnyMethod();
                    }
                });
            });
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            using (var scope = app.ApplicationServices.CreateScope())
            {
                var dbContext = scope.ServiceProvider.GetRequiredService<DonationDBContext>();
                dbContext.Database.Migrate();
            }

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseCors("FrontendPolicy");
            app.UseRouting();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapGet("/", async context =>
                {
                    await context.Response.WriteAsync("Backend is Healthy");
                });
                endpoints.MapControllers();
            });
        }
    }
}
