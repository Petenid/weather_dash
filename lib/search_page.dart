import 'package:flutter/material.dart';

import 'location.dart';
import 'places.dart';

class CitySearchPage extends StatefulWidget {
  const CitySearchPage({super.key});

  @override
  State<CitySearchPage> createState() => _CitySearchPageState();
}

class _CitySearchPageState extends State<CitySearchPage> {
  final _controller = TextEditingController();
  Future<List<Place>>? _results;
  bool _locating = false;
  String? _locationError;

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final here = await locateMe();
      if (!mounted) return;
      Navigator.pop(context, here);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.length < 2) return;
    setState(() {
      _results = searchPlaces(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a city')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'City or town, like North Bay or Paris, France',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Search',
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_locating ? 'Finding you…' : 'Use my location'),
              ),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _locationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_results == null) {
      return const Center(
        child: Text(
          'Type a city or town, then press Enter.\n'
          'Add a province or country after a comma to narrow it down.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return FutureBuilder<List<Place>>(
      future: _results,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Search failed. ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final places = snapshot.data!;
        if (places.isEmpty) {
          return const Center(
            child: Text('No places match that name. Check the spelling, or try a larger town nearby.'),
          );
        }

        return ListView.builder(
          itemCount: places.length,
          itemBuilder: (context, i) {
            final place = places[i];
            return ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(place.name),
              subtitle: Text(place.details),
              onTap: () => Navigator.pop(context, place),
            );
          },
        );
      },
    );
  }
}