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

import {
  getLatestCounties,
  getNationalEnrollmentTrend,
  getStateEnrollmentTrend,
  getStateOptions,
  getMedicareEnrollmentOperationsStatus
} from "./api/medicareEnrollmentApi";

import type {
  MedicareEnrollmentCountyLatest,
  MedicareEnrollmentNationalTrend,
  MedicareEnrollmentStateOption,
  MedicareEnrollmentStateTrend,
  DataOperationsStatus
} from "./types/medicareEnrollment";

import "./App.css";

type EnrollmentTrend =
    | MedicareEnrollmentNationalTrend
    | MedicareEnrollmentStateTrend;

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

function formatDateTime(dateValue: string | null): string {
  if (!dateValue) {
    return "Not available";
  }

  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit"
  }).format(new Date(`${dateValue}Z`));
}

function App() {
  const [data, setData] = useState<EnrollmentTrend[]>([]);

  const [states, setStates] =
      useState<MedicareEnrollmentStateOption[]>([]);

  const [counties, setCounties] =
      useState<MedicareEnrollmentCountyLatest[]>([]);

  const [selectedRegion, setSelectedRegion] = useState("US");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [showAllCounties, setShowAllCounties] =
      useState(false);

  const displayedCounties =
      showAllCounties
          ? counties
          : counties.slice(0, 10);

  const [operationsStatus, setOperationsStatus] =
      useState<DataOperationsStatus | null>(null);

  useEffect(() => {
    getStateOptions()
        .then(setStates)
        .catch((err: unknown) => {
          console.error(
              "Failed to load state options",
              err
          );
        });
  }, []);

  useEffect(() => {
    async function loadData() {
      try {
        setIsLoading(true);
        setError(null);

        const results =
            selectedRegion === "US"
                ? await getNationalEnrollmentTrend()
                : await getStateEnrollmentTrend(
                    selectedRegion
                );

        setData(results);
      } catch (err: unknown) {
        setError(
            err instanceof Error
                ? err.message
                : "Unable to load enrollment data."
        );
      } finally {
        setIsLoading(false);
      }
    }

    loadData();
  }, [selectedRegion]);

  useEffect(() => {
    if (selectedRegion === "US") {
      setCounties([]);
      return;
    }

    getLatestCounties(selectedRegion)
        .then(setCounties)
        .catch((err: unknown) => {
          console.error(
              "Failed to load county data",
              err
          );

          setCounties([]);
        });
  }, [selectedRegion]);

  useEffect(() => {
    setShowAllCounties(false);
  }, [selectedRegion]);

  useEffect(() => {
    getMedicareEnrollmentOperationsStatus()
        .then(setOperationsStatus)
        .catch((err: unknown) => {
          console.error(
              "Failed to load data operations status",
              err
          );
        });
  }, []);

  const latest = useMemo(() => {
    return data.length > 0
        ? data[data.length - 1]
        : null;
  }, [data]);

  const selectedName =
      selectedRegion === "US"
          ? "National"
          : states.find(
          (state) =>
              state.stateCode === selectedRegion
      )?.stateName ?? selectedRegion;

  if (isLoading && data.length === 0) {
    return (
        <main className="page">
          Loading HealthcareHub...
        </main>
    );
  }

  return (
      <main className="page">
        <header className="page-header">
          <div>
            <p className="eyebrow">
              HealthcareHub
            </p>

            <h1>Medicare Enrollment</h1>

            <p className="subtitle">
              Medicare enrollment trends from CMS
              public data.
            </p>
          </div>

          {latest && (
              <div className="freshness">
                Latest reporting period

                <strong>
                  {formatMonth(
                      latest.reportingPeriodStart
                  )}
                </strong>
              </div>
          )}
        </header>

        <section className="controls">
          <label htmlFor="region-select">
            Geography
          </label>

          <select
              id="region-select"
              value={selectedRegion}
              onChange={(event) =>
                  setSelectedRegion(
                      event.target.value
                  )
              }
          >
            <option value="US">
              National
            </option>

            {states.map((state) => (
                <option
                    key={state.stateCode}
                    value={state.stateCode}
                >
                  {state.stateName}
                </option>
            ))}
          </select>
        </section>

        {error && (
            <p className="error">
              {error}
            </p>
        )}

        {latest && (
            <>
              <section className="metrics">
                <article className="metric-card">
              <span>
                Total beneficiaries
              </span>

                  <strong>
                    {formatNumber(
                        latest.totalBeneficiaries
                    )}
                  </strong>
                </article>

                <article className="metric-card">
              <span>
                Original Medicare
              </span>

                  <strong>
                    {formatNumber(
                        latest.originalMedicareBeneficiaries
                    )}
                  </strong>
                </article>

                <article className="metric-card">
              <span>
                Medicare Advantage & other
              </span>

                  <strong>
                    {formatNumber(
                        latest.medicareAdvantageAndOtherBeneficiaries
                    )}
                  </strong>
                </article>

                <article className="metric-card">
              <span>
                Medicare Advantage share
              </span>

                  <strong>
                    {latest.medicareAdvantagePercent
                        ?.toFixed(2) ?? "—"}
                    %
                  </strong>
                </article>
              </section>

              <section className="chart-card">
                <div className="section-heading">
                  <div>
                    <h2>
                      {selectedName} enrollment trend
                    </h2>

                    <p>
                      Monthly Medicare beneficiary
                      enrollment since January 2020.
                    </p>
                  </div>
                </div>

                <div className="chart-container">
                  <ResponsiveContainer
                      width="100%"
                      height="100%"
                  >
                    <LineChart data={data}>
                      <CartesianGrid
                          strokeDasharray="3 3"
                      />

                      <XAxis
                          dataKey="reportingPeriodStart"
                          tickFormatter={formatMonth}
                          minTickGap={40}
                      />

                      <YAxis
                          domain={[
                            (dataMin: number) =>
                                Math.floor(
                                    dataMin * 0.95
                                ),
                            (dataMax: number) =>
                                Math.ceil(
                                    dataMax * 1.05
                                )
                          ]}
                          tickFormatter={(
                              value: number
                          ) => {
                            if (
                                value >= 1_000_000
                            ) {
                              return `${(
                                  value / 1_000_000
                              ).toFixed(1)}M`;
                            }

                            return `${Math.round(
                                value / 1_000
                            )}K`;
                          }}
                          width={60}
                      />

                      <Tooltip
                          labelFormatter={(value) =>
                              formatMonth(
                                  String(value)
                              )
                          }
                          formatter={(value) =>
                              formatNumber(
                                  Number(value)
                              )
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

              {selectedRegion !== "US" && counties.length > 0 && (
                  <section className="county-card">
                    <div className="section-heading">
                      <div>
                        <h2>Latest county enrollment</h2>

                        <p>
                          Latest available Medicare enrollment by county for{" "}
                          {selectedName}.
                        </p>
                      </div>
                    </div>

                    <div className="county-table-wrapper">
                      <table className="county-table">
                        <thead>
                        <tr>
                          <th>County</th>
                          <th>Total beneficiaries</th>
                          <th>Original Medicare</th>
                          <th>Medicare Advantage</th>
                          <th>MA share</th>
                        </tr>
                        </thead>

                        <tbody>
                        {displayedCounties.map((county) => (
                            <tr key={county.fipsCode}>
                              <td>{county.countyName}</td>

                              <td>
                                {formatNumber(
                                    county.totalBeneficiaries
                                )}
                              </td>

                              <td>
                                {formatNumber(
                                    county.originalMedicareBeneficiaries
                                )}
                              </td>

                              <td>
                                {formatNumber(
                                    county.medicareAdvantageAndOtherBeneficiaries
                                )}
                              </td>

                              <td>
                                {county.medicareAdvantagePercent?.toFixed(2) ?? "—"}%
                              </td>
                            </tr>
                        ))}
                        </tbody>
                      </table>

                      {counties.length > 10 && (
                          <button
                              type="button"
                              className="county-toggle"
                              onClick={() =>
                                  setShowAllCounties(
                                      (current) => !current
                                  )
                              }
                          >
                            {showAllCounties
                                ? "Show top 10"
                                : `Show all ${counties.length} counties`}
                          </button>
                      )}
                    </div>
                  </section>
              )}

              {operationsStatus && (
                  <section className="operations-card">
                    <div className="section-heading">
                      <div>
                        <h2>Data operations</h2>

                        <p>
                          Source freshness and latest HealthcareHub ingestion status.
                        </p>
                      </div>

                      <span
                          className={`status-badge ${
                              operationsStatus.status.toLowerCase() === "success"
                                  ? "status-success"
                                  : "status-warning"
                          }`}
                      >
        {operationsStatus.status}
      </span>
                    </div>

                    <div className="operations-grid">
                      <div>
                        <span>Source</span>
                        <strong>
                          {operationsStatus.sourceName}
                        </strong>
                      </div>

                      <div>
                        <span>Agency</span>
                        <strong>
                          {operationsStatus.sourceAgency}
                        </strong>
                      </div>

                      <div>
                        <span>Cadence</span>
                        <strong>
                          {operationsStatus.reportingCadence ?? "Not available"}
                        </strong>
                      </div>

                      <div>
                        <span>Geographic grain</span>
                        <strong>
                          {operationsStatus.geographicGrain ?? "Not available"}
                        </strong>
                      </div>

                      <div>
                        <span>Pipeline run</span>
                        <strong>
                          #{operationsStatus.pipelineRunId}
                        </strong>
                      </div>

                      <div>
                        <span>Completed</span>
                        <strong>
                          {formatDateTime(
                              operationsStatus.completedUtc
                          )}
                        </strong>
                      </div>

                      <div>
                        <span>Rows processed</span>
                        <strong>
                          {formatNumber(
                              operationsStatus.rowsRead
                          )}
                        </strong>
                      </div>

                      <div>
                        <span>Rows rejected</span>
                        <strong>
                          {formatNumber(
                              operationsStatus.rowsRejected
                          )}
                        </strong>
                      </div>
                    </div>

                    <div className="source-link-row">
                      <a
                          href={operationsStatus.sourceUrl}
                          target="_blank"
                          rel="noreferrer"
                      >
                        View CMS source
                      </a>
                    </div>
                  </section>
              )}
            </>
        )}
      </main>
  );
}

export default App;