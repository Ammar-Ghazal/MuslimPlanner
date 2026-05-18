import SwiftUI

struct OnboardingView: View {
    let settings: AppSettings
    @EnvironmentObject var locationService: LocationService
    @State private var step = 0

    var body: some View {
        TabView(selection: $step) {
            WelcomeStep(onNext: { step = 1 })
                .tag(0)
            LocationStep(settings: settings, onNext: { step = 2 })
                .tag(1)
            MethodStep(settings: settings, onDone: finish)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut, value: step)
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("Prayer Planner")
                .font(.largeTitle.bold())
            Text("Organize your day around the five daily prayers — your anchor points for a structured, purposeful day.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Button(action: onNext) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Location

private struct LocationStep: View {
    let settings: AppSettings
    let onNext: () -> Void
    @EnvironmentObject var locationService: LocationService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Your Location")
                .font(.largeTitle.bold())
            Text("Prayer Planner needs your location to calculate accurate prayer times for your city.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            if locationService.isAuthorized {
                Label(locationService.cityName.isEmpty ? "Location found" : locationService.cityName,
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if locationService.isDenied {
                Text("Location access denied. Please enable it in Settings.")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            if !locationService.isAuthorized && !locationService.isDenied {
                Button("Allow Location Access") {
                    locationService.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .padding(.horizontal, 32)
            }

            Button(locationService.isAuthorized ? "Continue" : "Skip for now", action: onNext)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .onChange(of: locationService.isAuthorized) {
            if locationService.isAuthorized {
                locationService.fetchLocation()
            }
        }
    }
}

// MARK: - Method

private struct MethodStep: View {
    let settings: AppSettings
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            Text("Calculation Method")
                .font(.largeTitle.bold())
            Text("Choose the authority used to calculate prayer times.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 0) {
                ForEach(PrayerTimeService.calculationMethods, id: \.id) { method in
                    Button {
                        settings.calculationMethod = method.id
                    } label: {
                        HStack {
                            Text(method.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if settings.calculationMethod == method.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                    }
                    Divider().padding(.leading)
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onDone) {
                Text("Start Planning")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}
