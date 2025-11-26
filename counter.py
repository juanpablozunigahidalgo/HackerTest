from collections import Counter

def reduceCapacity(model):
    n = len(model)
    # ceiling of n/2, using integers only
    target = (n + 1) // 2

    freq = list(Counter(model).values())
    freq.sort(reverse=True)

    total = 0
    models_used = 0

    for f in freq:
        total += f
        models_used += 1
        if total >= target:
            return models_used

    return models_used
