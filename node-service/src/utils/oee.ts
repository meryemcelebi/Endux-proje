export function roundOeeValue(value: number, digits = 2): number {
    const factor = 10 ** digits;
    return Math.round(value * factor) / factor;
}

export function calculateOeeScore(
    availability?: number | null,
    performance?: number | null,
    quality?: number | null,
    digits = 2
): number | null {
    if (availability == null || performance == null || quality == null) {
        return null;
    }

    return roundOeeValue((availability * performance * quality) / 10000, digits);
}

export function averageOeeComponents<T>(
    records: T[],
    selectors: {
        availability: (record: T) => number | null | undefined;
        performance: (record: T) => number | null | undefined;
        quality: (record: T) => number | null | undefined;
    }
) {
    const totals = records.reduce(
        (acc, record) => {
            const availability = selectors.availability(record);
            const performance = selectors.performance(record);
            const quality = selectors.quality(record);

            if (availability != null) {
                acc.availability += availability;
                acc.availabilityCount += 1;
            }
            if (performance != null) {
                acc.performance += performance;
                acc.performanceCount += 1;
            }
            if (quality != null) {
                acc.quality += quality;
                acc.qualityCount += 1;
            }

            return acc;
        },
        {
            availability: 0,
            availabilityCount: 0,
            performance: 0,
            performanceCount: 0,
            quality: 0,
            qualityCount: 0,
        }
    );

    const availability = totals.availabilityCount
        ? roundOeeValue(totals.availability / totals.availabilityCount)
        : 0;
    const performance = totals.performanceCount
        ? roundOeeValue(totals.performance / totals.performanceCount)
        : 0;
    const quality = totals.qualityCount
        ? roundOeeValue(totals.quality / totals.qualityCount)
        : 0;

    return {
        availability,
        performance,
        quality,
        oee: calculateOeeScore(availability, performance, quality) ?? 0,
    };
}
