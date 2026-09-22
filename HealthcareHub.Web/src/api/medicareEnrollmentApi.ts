import type {
    MedicareEnrollmentNationalTrend,
    MedicareEnrollmentStateOption,
    MedicareEnrollmentStateTrend
} from "../types/medicareEnrollment";

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

export async function getStateEnrollmentTrend(
    stateCode: string
): Promise<MedicareEnrollmentStateTrend[]> {

    const response = await fetch(
        `${apiBaseUrl}/api/medicare/enrollment/states/${stateCode}`
    );

    if (!response.ok) {
        throw new Error(
            `Failed to load state Medicare enrollment data: ${response.status}`
        );
    }

    return response.json();
}

export async function getStateOptions():
    Promise<MedicareEnrollmentStateOption[]> {

    const response = await fetch(
        `${apiBaseUrl}/api/medicare/enrollment/states`
    );

    if (!response.ok) {
        throw new Error(
            `Failed to load state options: ${response.status}`
        );
    }

    return response.json();
}

export async function getLatestCounties(
    stateCode: string
): Promise<MedicareEnrollmentCountyLatest[]> {

    const response = await fetch(
        `${apiBaseUrl}/api/medicare/enrollment/counties/${stateCode}`
    );

    if (!response.ok) {
        throw new Error(
            `Failed to load county Medicare enrollment data: ${response.status}`
        );
    }

    return response.json();
}

export async function getMedicareEnrollmentOperationsStatus():
    Promise<DataOperationsStatus> {

    const response = await fetch(
        `${apiBaseUrl}/api/data-operations/medicare-enrollment`
    );

    if (!response.ok) {
        throw new Error(
            `Failed to load data operations status: ${response.status}`
        );
    }

    return response.json();
}