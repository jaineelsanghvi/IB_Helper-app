import SwiftUI

struct ResourceLibraryView: View {
    @State private var expandedSections: [Bool] = Array(repeating: false, count: 11)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Resource Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                // Math Section
                DisclosureGroup(isExpanded: $expandedSections[0]) {
                    ResourceSection(links: [
                        ("Calculus Basics", "https://www.khanacademy.org/math/calculus-1"),
                        ("Algebra", "https://www.khanacademy.org/math/algebra"),
                        ("Geometry", "https://www.khanacademy.org/math/geometry"),
                        ("Statistics", "https://www.khanacademy.org/math/statistics-probability"),
                        ("Trigonometry", "https://www.khanacademy.org/math/trigonometry")
                    ])
                } label: {
                    Text("Math")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Computer Science Section
                DisclosureGroup(isExpanded: $expandedSections[1]) {
                    ResourceSection(links: [
                        ("Programming Basics", "https://www.codecademy.com/learn/learn-how-to-code"),
                        ("Data Structures", "https://www.geeksforgeeks.org/data-structures/"),
                        ("Algorithms", "https://www.khanacademy.org/computing/computer-science/algorithms"),
                        ("Computer Architecture", "https://www.coursera.org/learn/computer-architecture"),
                        ("Operating Systems", "https://www.udacity.com/course/introduction-to-operating-systems--ud923")
                    ])
                } label: {
                    Text("Computer Science")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // History Section
                DisclosureGroup(isExpanded: $expandedSections[2]) {
                    ResourceSection(links: [
                        ("Ancient Civilizations", "https://www.ancient.eu/"),
                        ("Middle Ages", "https://www.britannica.com/event/Middle-Ages"),
                        ("Modern History", "https://www.khanacademy.org/humanities/world-history"),
                        ("Recent History", "https://www.bbc.com/news/world"),
                        ("Renaissance", "https://www.history.com/topics/renaissance/renaissance")
                    ])
                } label: {
                    Text("History")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Geography Section
                DisclosureGroup(isExpanded: $expandedSections[3]) {
                    ResourceSection(links: [
                        ("Physical Geography", "https://www.nationalgeographic.org/encyclopedia/physical-geography/"),
                        ("Human Geography", "https://www.nationalgeographic.org/encyclopedia/human-geography/"),
                        ("Environmental Geography", "https://www.worldatlas.com/geography"),
                        ("Geographical Techniques", "https://www.esri.com/en-us/home"),
                        ("Geopolitics", "https://www.cfr.org/geopolitics")
                    ])
                } label: {
                    Text("Geography")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Physics Section
                DisclosureGroup(isExpanded: $expandedSections[4]) {
                    ResourceSection(links: [
                        ("Mechanics", "https://www.khanacademy.org/science/physics"),
                        ("Electromagnetism", "https://www.khanacademy.org/science/physics/magnetic-forces-and-magnetic-fields"),
                        ("Optics", "https://www.physicsclassroom.com/class/refrn"),
                        ("Thermodynamics", "https://www.khanacademy.org/science/physics/thermodynamics")
                    ])
                } label: {
                    Text("Physics")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Biology Section
                DisclosureGroup(isExpanded: $expandedSections[5]) {
                    ResourceSection(links: [
                        ("Cell Biology", "https://www.khanacademy.org/science/biology/cell-biology"),
                        ("Genetics", "https://www.khanacademy.org/science/biology/heredity"),
                        ("Ecology", "https://www.khanacademy.org/science/biology/ecology")
                    ])
                } label: {
                    Text("Biology")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Chemistry Section
                DisclosureGroup(isExpanded: $expandedSections[6]) {
                    ResourceSection(links: [
                        ("Atomic Structure", "https://www.khanacademy.org/science/chemistry/atomic-structure"),
                        ("Chemical Reactions", "https://www.khanacademy.org/science/chemistry/chemical-reactions-stoichiome"),
                        ("Thermochemistry", "https://www.khanacademy.org/science/chemistry/thermochemistry-chem")
                    ])
                } label: {
                    Text("Chemistry")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Economics Section
                DisclosureGroup(isExpanded: $expandedSections[7]) {
                    ResourceSection(links: [
                        ("Microeconomics", "https://www.investopedia.com/microeconomics-5189403"),
                        ("Macroeconomics", "https://www.investopedia.com/macroeconomics-5189432"),
                        ("Monetary Policy", "https://www.federalreserve.gov/monetarypolicy.htm")
                    ])
                } label: {
                    Text("Economics")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Environmental Studies Section
                DisclosureGroup(isExpanded: $expandedSections[8]) {
                    ResourceSection(links: [
                        ("Sustainability", "https://www.un.org/sustainabledevelopment/sustainable-development-goals/"),
                        ("Pollution", "https://www.nationalgeographic.org/encyclopedia/pollution/"),
                        ("Climate Change", "https://climate.nasa.gov/")
                    ])
                } label: {
                    Text("Environmental Studies")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Business Studies Section
                DisclosureGroup(isExpanded: $expandedSections[9]) {
                    ResourceSection(links: [
                        ("Marketing", "https://www.investopedia.com/terms/m/marketing.asp"),
                        ("Finance", "https://www.khanacademy.org/economics-finance-domain/core-finance"),
                        ("Management", "https://www.mindtools.com/pages/main/newMN_MPM.htm")
                    ])
                } label: {
                    Text("Business Studies")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Spanish Section
                DisclosureGroup(isExpanded: $expandedSections[10]) {
                    ResourceSection(links: [
                        ("Basics", "https://www.duolingo.com/course/es/en/Learn-Spanish"),
                        ("Grammar", "https://studyspanish.com/grammar"),
                        ("Vocabulary", "https://www.spanishdict.com/vocabulary")
                    ])
                } label: {
                    Text("Spanish")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
}

// Helper Component for Displaying Links
struct ResourceSection: View {
    var links: [(title: String, url: String)]
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(links, id: \.title) { link in
                if let url = URL(string: link.url) {
                    Link(link.title, destination: url)
                        .font(.body)
                        .foregroundColor(.blue)
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(.leading)
    }
}




