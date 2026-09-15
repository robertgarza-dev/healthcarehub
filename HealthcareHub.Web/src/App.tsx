import { useEffect, useMemo, useState } from "react";
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis
} from "recharts";

import { getNationalEnrollmentTrend } from "./api/medicareEnrollmentApi";
import type { MedicareEnrollmentNationalTrend } from "./types/medicareEnrollment";
import "./App.css";

function formatNumber(value: number | null): string {
  if (value === null) {
    return "Not available";
  }

  return new Intl.NumberFormat("en-US").format(value);
}

function formatMonth(dateValue: string): string {
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short"
  }).format(new Date(dateValue));
}

function App() {
  const [data, setData] =
      useState<MedicareEnrollmentNationalTrend[]>([]);

  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getNationalEnrollmentTrend()
        .then(setData)
        .catch((err: unknown) => {
          setError(
              err instanceof Error
                  ? err.message
                  : "Unable to load enrollment data."
          );
        })
        .finally(() => setIsLoading(false));
  }, []);

  const latest = useMemo(() => {
    return data.length > 0 ? data[data.length - 1] : null;
  }, [data]);

  if (isLoading) {
    return <main className="page">Loading HealthcareHub...</main>;
  }

  if (error) {
    return (
        <main className="page">
          <h1>HealthcareHub</h1>
          <p className="error">{error}</p>
        </main>
    );
  }

  return (
      <main className="page">
        <header className="page-header">
          <div>
            <p className="eyebrow">HealthcareHub</p>
            <h1>Medicare Enrollment</h1>
            <p className="subtitle">
              National Medicare enrollment trends from CMS public data.
            </p>
          </div>

          {latest && (
              <div className="freshness">
                Latest reporting period
                <strong>{formatMonth(latest.reportingPeriodStart)}</strong>
              </div>
          )}
        </header>

        {latest && (
            <section className="metrics">
              <article className="metric-card">
                <span>Total beneficiaries</span>
                <strong>
                  {formatNumber(latest.totalBeneficiaries)}
                </strong>
              </article>

              <article className="metric-card">
                <span>Original Medicare</span>
                <strong>
                  {formatNumber(
                      latest.originalMedicareBeneficiaries
                  )}
                </strong>
              </article>

              <article className="metric-card">
                <span>Medicare Advantage & other</span>
                <strong>
                  {formatNumber(
                      latest.medicareAdvantageAndOtherBeneficiaries
                  )}
                </strong>
              </article>

              <article className="metric-card">
                <span>Medicare Advantage share</span>
                <strong>
                  {latest.medicareAdvantagePercent?.toFixed(2) ?? "—"}%
                </strong>
              </article>
            </section>
        )}

        <section className="chart-card">
          <div className="section-heading">
            <div>
              <h2>National enrollment trend</h2>
              <p>
                Monthly Medicare beneficiary enrollment since January 2020.
              </p>
            </div>
          </div>

          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis
                    dataKey="reportingPeriodStart"
                    tickFormatter={formatMonth}
                    minTickGap={40}
                />
                <YAxis
                    tickFormatter={(value: number) =>
                        `${(value / 1_000_000).toFixed(0)}M`
                    }
                    width={50}
                />
                <Tooltip
                    labelFormatter={(value) =>
                        formatMonth(String(value))
                    }
                    formatter={(value) =>
                        formatNumber(Number(value))
                    }
                />
                <Line
                    type="monotone"
                    dataKey="totalBeneficiaries"
                    name="Total beneficiaries"
                    strokeWidth={2}
                    dot={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </section>
      </main>
  );
}

export default App;