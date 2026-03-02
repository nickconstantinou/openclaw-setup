---
name: mobile-app-dev
description: Standards for React Native, Expo, and NativeWind development.
---

# Mobile Application Development Skill

This skill defines the standards for building the ExamPulse mobile/web frontend using Expo and NativeWind.

## 1. Routing (Expo Router)
- **File-based Routing**: Use the `app/` directory structure.
- **Dynamic Routes**: Use `[id].tsx` for dynamic segments.
- **Groups**: Use `(tabs)` or `(auth)` groups to organize layouts without affecting URLs.
- **Linking**: Use `<Link href="/...">` or `router.push()`. Avoid React Navigation actions directly.

## 2. Styling (NativeWind)
- **Class Implementation**: Use `className="..."` for all styling.
- **No StyleSheet**: Avoid `StyleSheet.create` unless absolutely necessary for complex reanimated shared values.
- **Safe Areas**: Use `SafeAreaView` from `react-native-safe-area-context` for root screens.
- **Text**: Always wrap text strings in `<Text>` components.

## 3. Web Compatibility
- **Cross-Platform**: The app runs on Web, iOS, and Android.
- **Platform Checks**: checking `Platform.OS === 'web'` to conditionally render DOM-only libraries (like `reactflow` or `framer-motion`).
- **Responsive**: Use NativeWind responsive prefixes (e.g., `md:flex-row`).

## 4. Components
- **Functional**: Use React Functional Components.
- **Props**: Define strictly typed Props interfaces.
- **Images**: Use `expo-image` for optimized loading if available, or RN `Image` with caching strategy.
