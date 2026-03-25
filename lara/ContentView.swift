//
//  ContentView.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var uid: uid_t = getuid()
    @State private var pid: pid_t = getpid()

    var body: some View {
        NavigationStack {
            List {
                Section("Kernel Read Write") {
                    Button(mgr.dsrunning ? "Running..." : "Run Exploit") {
                        mgr.run()
                    }
                    .disabled(mgr.dsrunning)
                    
                    HStack {
                        Text("krw ready?")
                        Spacer()
                        Text(mgr.dsready ? "Yes" : "No")
                            .foregroundColor(mgr.dsready ? .green : .red)
                    }
                    
                    HStack {
                        Text("kernel_base:")
                        Spacer()
                        Text(String(format: "0x%llx", mgr.kernbase))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("kernel_slide:")
                        Spacer()
                        Text(String(format: "0x%llx", mgr.kernslide))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("File system") {
                    Button("Get Proc") {
                        print(procbyid())
                    }
                    .disabled(!mgr.dsready)
                    
                    HStack {
                        Text("UID:")
                        
                        Spacer()
                        
                        Text("\(uid)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Button {
                            uid = getuid()
                            print(uid)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    
                    HStack {
                        Text("PID:")
                        
                        Spacer()
                        
                        Text("\(pid)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Button {
                            pid = getpid()
                            print(pid)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                
                Section {
                    Button("panic!") {
                        mgr.panic()
                    }
                    .disabled(!mgr.dsready)
                } header: {
                    Text("Other")
                }
                
                Section {
                    HStack(alignment: .top) {
                        AsyncImage(url: URL(string: "https://github.com/rooootdev.png")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("roooot")
                                .font(.headline)
                            
                            Text("Main Developer")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/rooootdev"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        AsyncImage(url: URL(string: "https://github.com/AppInstalleriOSGH.png")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("AppInstaller iOS")
                                .font(.headline)
                            
                            Text("Helped me with offsets and other stuff. This project wouldnt have been possible without him!")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/khanhduytran0"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Credits")
                }
            }
            .navigationTitle("lara")
        }
    }
}
