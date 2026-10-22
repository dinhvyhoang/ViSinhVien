using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace ViSinhVien.Api.Migrations
{
    /// <inheritdoc />
    public partial class CompleteFinanceFeatures : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Seed category definitions only; never invent transactions or limits.
            migrationBuilder.Sql("""
                INSERT INTO categories (name, type, is_archived)
                SELECT seed.name, seed.type, FALSE FROM (VALUES
                    ('Tiền trọ', 'expense'), ('Giải trí', 'expense'), ('Chi khác', 'expense'),
                    ('Học bổng', 'income'), ('Thu khác', 'income')
                ) AS seed(name, type)
                WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE lower(c.name) = lower(seed.name) AND c.type = seed.type);
                """);
            migrationBuilder.CreateTable(
                name: "category_budgets",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    budget_month = table.Column<DateOnly>(type: "date", nullable: false),
                    category_id = table.Column<long>(type: "bigint", nullable: false),
                    limit_vnd = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_category_budgets", x => x.id);
                    table.CheckConstraint("ck_category_budget_limit", "limit_vnd > 0 AND limit_vnd <= 1000000000000");
                    table.CheckConstraint("ck_category_budget_month", "EXTRACT(DAY FROM budget_month) = 1");
                    table.ForeignKey(
                        name: "FK_category_budgets_categories_category_id",
                        column: x => x.category_id,
                        principalTable: "categories",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "user_profile",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false),
                    display_name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_profile", x => x.id);
                    table.CheckConstraint("ck_single_profile", "id = 1");
                });

            migrationBuilder.CreateIndex(
                name: "IX_category_budgets_budget_month_category_id",
                table: "category_budgets",
                columns: new[] { "budget_month", "category_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_category_budgets_category_id",
                table: "category_budgets",
                column: "category_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "category_budgets");

            migrationBuilder.DropTable(
                name: "user_profile");
        }
    }
}
