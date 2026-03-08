sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) {
    final self = this;
    if (self is Success<T, E>) {
      return onSuccess(self.value);
    }
    return onFailure((self as Failure<T, E>).error);
  }
}

final class Success<T, E> extends Result<T, E> {
  const Success(this.value);

  final T value;
}

final class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);

  final E error;
}
