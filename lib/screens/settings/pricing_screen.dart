import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/brand/brand.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';

/// Account screen. Commercial terms are not listed in the app.
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = Brand.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(brand.productName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/config'),
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${brand.productName} runs on a computer at the client. '
                'Sign-in is for the tunnel and for sync.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
