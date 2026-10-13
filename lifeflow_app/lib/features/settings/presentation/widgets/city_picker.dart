import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/location_service.dart';
import '../../domain/weather_location.dart';
import '../providers/settings_provider.dart';

Future<void> showCityPicker(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _CityPickerDialog());
}

class _CityPickerDialog extends ConsumerStatefulWidget {
  const _CityPickerDialog();

  @override
  ConsumerState<_CityPickerDialog> createState() => _CityPickerDialogState();
}

class _CityPickerDialogState extends ConsumerState<_CityPickerDialog> {
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  int _searchId = 0;

  List<WeatherLocation> _results = const [];
  bool _searching = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    // Drop responses that arrive after a newer search has started.
    final id = ++_searchId;
    if (query.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(locationServiceProvider).search(query);
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = results;
        _error = results.isEmpty ? 'No cities found for "${query.trim()}".' : null;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() => _error = "Couldn't search right now. Check your connection.");
    } finally {
      if (mounted && id == _searchId) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final location = await ref.read(locationServiceProvider).current();
      await _select(location);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is LocationException
          ? e.message
          : "Couldn't get your location. Try searching for your city instead.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _select(WeatherLocation location) async {
    await ref.read(weatherLocationProvider.notifier).set(location);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(weatherLocationProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Weather location', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Currently ${current.label}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(_locating ? 'Finding you…' : 'Use my current location'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _queryCtrl,
                autofocus: true,
                onChanged: _onQueryChanged,
                onSubmitted: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search for a city',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final result = _results[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(result.name),
                      subtitle: result.detail.isEmpty ? null : Text(result.detail),
                      onTap: () => _select(result),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
