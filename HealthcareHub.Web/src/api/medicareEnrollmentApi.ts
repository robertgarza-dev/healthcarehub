import type { MedicareEnrollmentNationalTrend } from "../types/medicareEnrollment";

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;

export async function getNationalEnrollmentTrend():
    Promise<MedicareEnrollmentNationalTrend[]> {

    const response = await fetch(
        `${apiBaseUrl}/api/medicare/enrollment/national`
    );

    if (!response.ok) {
        throw new Error(
            `Failed to load Medicare enrollment data: ${response.status}`
        );
    }

    return response.json();
}