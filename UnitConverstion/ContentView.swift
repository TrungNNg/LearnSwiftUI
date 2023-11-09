//
//  ContentView.swift
//  UnitConverstion
//
//  Created by Trung Nguyen on 10/11/23.
//


import CoreData
import SwiftUI

struct ContentView: View {
    @StateObject var model = DessertModel()
    var body: some View {
        //UnitConvert()
        //GuessTheFlag()
        //WeTip()
        //One2Three()
        //BetterRest()
        //Scramble()
        //AnimationTest()
        //iExpense()
       // Moonshot()
        //HabitTracking(habitApp: HabitApp())
        //CupcakeView()
        //AddBookView()
        //UserView()
        MealMainView(dessertData: model)
    }
}

struct MealMainView: View {
    @ObservedObject var dessertData: DessertModel
    @State private var isLoading = true
    @State private var loadingFailed = false
    
    @State private var sortOption = DessertModel.SortOption.alphabetically
    @State private var darkMode = false
    
    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView()
            } else if loadingFailed {
                Text("Fetch data failed") // TODO: replace with better view
            } else {
                List {
                    Section {
                        Picker(selection: $sortOption, content: {
                            ForEach(DessertModel.SortOption.allCases) { option in
                                Text(option.rawValue)
                            }
                        }) {
                            Text("Sort option")
                        }
                        .onChange(of: sortOption) { newOption in
                            dessertData.changeSortOption(option: newOption)
                        }
                    }
                    Section {
                        ForEach(dessertData.mealsThumpNails, id: \.self) { thumb in
                            NavigationLink {
                                MealDetailView(mealId: thumb.idMeal, model: dessertData)
                            } label: {
                                LoadAsyncImage(url: thumb.strMealThumb)
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(20)
                                VStack(alignment: .leading) {
                                    Text(thumb.strMeal)
                                        .font(.headline)
                                    Text("id:\(thumb.idMeal)")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                    } header: {
                        Text("Dessert list")
                    }
                }
                .animation(.default, value: dessertData.mealsThumpNails)
                .navigationTitle("Fetch Dessert")
                .navigationBarTitleDisplayMode(.inline)
                .preferredColorScheme(darkMode ? .dark : .light)
                .toolbar {
                    Button(action: {
                        darkMode.toggle()
                    }) {
                        Label("", systemImage: darkMode ? "moon.fill" : "moon")
                            .font(.headline)
                            .padding()
                    }
                }
            }
        }
        .task {
            do {
                try await dessertData.fetchMealThumbNails()
                dessertData.changeSortOption(option: .alphabetically)
            } catch let error {
                // we can handle different type of error here
                print("fetch meal thumbnails error: \(error)")
                loadingFailed = true
            }
            isLoading = false
        }
    }
    
}

struct MealDetailView: View {
    @State private var meal: MealDetail? = nil
    @State private var isLoading = true
    @State private var loadingFailed = false
    let mealId: String
    let model: DessertModel
    
    @State private var favorite = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if loadingFailed {
                Text("falied")
            } else if let meal = meal {
                ScrollView {
                    LoadAsyncImage(url: meal.strMealThumb)
                    VStack(alignment: .leading) {
                        if meal.strMeal != "" {
                            HStack {
                                Text(meal.strMeal)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(action: {
                                    favorite.toggle()
                                }) {
                                    Label("", systemImage: favorite ? "heart.fill" : "heart")
                                        .font(.title)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                            }
                        } else {
                            Text("Meal name unavailable")
                        }
                        Divider()
                        Text("Ingredients:")
                               .font(.headline)
                        IngredientAndMeasureView(ingredients: meal.strIngredients, measurements: meal.strMeasures)
                        Divider()
                        Text("Instructions:")
                                .font(.headline)
                                .padding(.top)
                        if meal.strInstructions != "" {
                            Text(meal.strInstructions)
                                .padding(.top,1)
                                .font(.body)
                        } else {
                            Text("Instruction unavailable")
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            do {
                meal = try await model.fetchMealWithID(id: mealId)
            } catch let error {
                loadingFailed = true
                print("fetch meal detail using id error: \(error)")
            }
            isLoading = false
        }
    }
    
    struct IngredientAndMeasureView: View {
        let ingredients: [String]
        let measurements: [String]
        var body: some View {
            if !ingredients.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(minimum: 100)),
                    GridItem(.flexible(minimum: 100))
                ], spacing: 12) {
                    ForEach(0..<ingredients.count, id: \.self) { index in
                        if ingredients[index] != "" && measurements[index] != "" {
                            Text(ingredients[index])
                            Text(measurements[index])
                        }
                    }
                }
            } else {
                Text("Ingredient unavaialbe")
            }
        }
    }
    
}

struct LoadAsyncImage: View {
    var url: String
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
            } else if phase.error != nil {
                Text("failed load image") // TODO: add failed image load view here, Or display default image instead
            } else {
                ProgressView()
            }
        }
    }
}


// Fetch Apprentiship take home assignment
// MODEL
class DessertModel: ObservableObject {
    @Published var mealsThumpNails: [MealThumbnail] = []
    
    func fetchMealThumbNails() async throws {
        guard let url = URL(string: "https://themealdb.com/api/json/v1/1/filter.php?c=Dessert") else {
            throw FetchMealThumbnailsError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode([String:[MealThumbnailDecode]].self, from: data)
            if let meals = result["meals"] {
                // updating UI need to be done in main thread
                DispatchQueue.main.async {
                    self.mealsThumpNails = meals.map{ MealThumbnail(mealDecode: $0) }
                }
            }
        } catch let error {
            throw error
        }
    }
    
    enum FetchMealThumbnailsError: Error {
        case invalidURL
    }
    
    func fetchMealWithID(id: String) async throws -> MealDetail? {
        guard let url = URL(string: "https://themealdb.com/api/json/v1/1/lookup.php?i=\(id)") else {
            throw FetchMealDetailError.invalidURL
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode([String:[MealDetailDecode]].self, from: data)
            if let meals = result["meals"], meals.count > 0 {
                return MealDetail(mealDecode: meals.first!)
            } else {
                throw FetchMealDetailError.invalidJSON
            }
        } catch let error {
            throw error
        }
    }
    
    enum FetchMealDetailError: Error {
        case invalidURL
        case invalidJSON
    }
    
    // Sort meal thumbnails
    enum SortOption: String, Identifiable, CaseIterable {
        case alphabetically = "alphabettically"
        case id = "id"
        var id: Self { self }
    }
    
    func changeSortOption(option: SortOption) {
        switch option {
        case .alphabetically:
            mealsThumpNails.sort { $0.strMeal < $1.strMeal }
        case .id:
            mealsThumpNails.sort { (obj1, obj2) in
                let id1 = obj1.idMeal
                let id2 = obj2.idMeal
                
                if id1.isEmpty {
                    return false
                } else if id2.isEmpty {
                    return true
                }
                
                if let numericId1 = Int(id1), let numbericId2 = Int(id2) {
                    return numericId1 < numbericId2
                }
                
                return false
            }
        }
    }
}

struct MealThumbnail: Codable, Hashable {
    let strMeal: String
    let strMealThumb: String
    let idMeal: String
    
    init(mealDecode: MealThumbnailDecode) {
        self.idMeal = mealDecode.idMeal ?? ""
        self.strMeal = mealDecode.strMeal ?? ""
        self.strMealThumb = mealDecode.strMealThumb ?? ""
    }
}

// Use to decode JSON
struct MealThumbnailDecode: Decodable {
    let strMeal: String?
    let strMealThumb: String?
    let idMeal: String?
}

struct MealDetail {
    let idMeal: String
    let strMeal: String
    let strDrinkAlternate: String
    let strCategory: String
    let strArea: String
    let strInstructions : String
    let strMealThumb: String
    let strTags: [String]
    let strYoutube: String
    
    let strIngredients: [String]
    let strMeasures: [String]
    
    let strSource: String
    let strImageSource: String
    let strCreativeCommonsConfirmed: String
    let dataModified: String
    
    init(mealDecode: MealDetailDecode) {
        self.idMeal = mealDecode.idMeal ?? ""
        self.strMeal = mealDecode.strMeal ?? ""
        self.strDrinkAlternate = mealDecode.strDrinkAlternate ?? ""
        self.strCategory = mealDecode.strCategory ?? ""
        self.strArea = mealDecode.strArea ?? ""
        self.strInstructions = mealDecode.strInstructions ?? ""
        self.strMealThumb = mealDecode.strMealThumb ?? ""
        self.strTags = mealDecode.strTags?.components(separatedBy: ",") ?? []
        self.strYoutube = mealDecode.strYoutube ?? ""
        
        // Ingredient and its measure will be match using index from 0 -> 19
        // perhaps a better way is to build a map with [Ingredient : Measure]
        var temp: [String] = []
        temp.append(mealDecode.strIngredient1 ?? "")
        temp.append(mealDecode.strIngredient2 ?? "")
        temp.append(mealDecode.strIngredient3 ?? "")
        temp.append(mealDecode.strIngredient4 ?? "")
        temp.append(mealDecode.strIngredient5 ?? "")
        temp.append(mealDecode.strIngredient6 ?? "")
        temp.append(mealDecode.strIngredient7 ?? "")
        temp.append(mealDecode.strIngredient8 ?? "")
        temp.append(mealDecode.strIngredient9 ?? "")
        temp.append(mealDecode.strIngredient10 ?? "")
        temp.append(mealDecode.strIngredient11 ?? "")
        temp.append(mealDecode.strIngredient12 ?? "")
        temp.append(mealDecode.strIngredient13 ?? "")
        temp.append(mealDecode.strIngredient14 ?? "")
        temp.append(mealDecode.strIngredient15 ?? "")
        temp.append(mealDecode.strIngredient16 ?? "")
        temp.append(mealDecode.strIngredient17 ?? "")
        temp.append(mealDecode.strIngredient18 ?? "")
        temp.append(mealDecode.strIngredient19 ?? "")
        temp.append(mealDecode.strIngredient20 ?? "")
        self.strIngredients = temp
        temp.removeAll()
        temp.append(mealDecode.strMeasure1 ?? "")
        temp.append(mealDecode.strMeasure2 ?? "")
        temp.append(mealDecode.strMeasure3 ?? "")
        temp.append(mealDecode.strMeasure4 ?? "")
        temp.append(mealDecode.strMeasure5 ?? "")
        temp.append(mealDecode.strMeasure6 ?? "")
        temp.append(mealDecode.strMeasure7 ?? "")
        temp.append(mealDecode.strMeasure8 ?? "")
        temp.append(mealDecode.strMeasure9 ?? "")
        temp.append(mealDecode.strMeasure10 ?? "")
        temp.append(mealDecode.strMeasure11 ?? "")
        temp.append(mealDecode.strMeasure12 ?? "")
        temp.append(mealDecode.strMeasure13 ?? "")
        temp.append(mealDecode.strMeasure14 ?? "")
        temp.append(mealDecode.strMeasure15 ?? "")
        temp.append(mealDecode.strMeasure16 ?? "")
        temp.append(mealDecode.strMeasure17 ?? "")
        temp.append(mealDecode.strMeasure18 ?? "")
        temp.append(mealDecode.strMeasure19 ?? "")
        temp.append(mealDecode.strMeasure20 ?? "")
        self.strMeasures = temp
        
        self.strSource = mealDecode.strSource ?? ""
        self.strImageSource = mealDecode.strImageSource ?? ""
        self.strCreativeCommonsConfirmed = mealDecode.strCreativeCommonsConfirmed ?? ""
        self.dataModified = mealDecode.dataModified ?? ""
    }
}

struct MealDetailDecode: Codable {
    let idMeal: String?
    let strMeal: String?
    let strDrinkAlternate: String?
    let strCategory: String?
    let strArea: String?
    let strInstructions : String?
    let strMealThumb: String?
    let strTags: String?
    let strYoutube: String?
    
    let strIngredient1: String?
    let strIngredient2: String?
    let strIngredient3: String?
    let strIngredient4: String?
    let strIngredient5: String?
    let strIngredient6: String?
    let strIngredient7: String?
    let strIngredient8: String?
    let strIngredient9: String?
    let strIngredient10: String?
    let strIngredient11: String?
    let strIngredient12: String?
    let strIngredient13: String?
    let strIngredient14: String?
    let strIngredient15: String?
    let strIngredient16: String?
    let strIngredient17: String?
    let strIngredient18: String?
    let strIngredient19: String?
    let strIngredient20: String?
    
    let strMeasure1: String?
    let strMeasure2: String?
    let strMeasure3: String?
    let strMeasure4: String?
    let strMeasure5: String?
    let strMeasure6: String?
    let strMeasure7: String?
    let strMeasure8: String?
    let strMeasure9: String?
    let strMeasure10: String?
    let strMeasure11: String?
    let strMeasure12: String?
    let strMeasure13: String?
    let strMeasure14: String?
    let strMeasure15: String?
    let strMeasure16: String?
    let strMeasure17: String?
    let strMeasure18: String?
    let strMeasure19: String?
    let strMeasure20: String?
    
    let strSource: String?
    let strImageSource: String?
    let strCreativeCommonsConfirmed: String?
    let dataModified: String?
}


// Day 60 Challenge
/*
struct UserView: View {
    @EnvironmentObject var userModel: DataModel
    
    //@StateObject var userModel = DataModel()
    var body: some View {
        NavigationStack {
            List(userModel.users) { user in
                NavigationLink {
                    UserDetail(user: user, users: userModel.users)
                } label: {
                    Text(user.name)
                }
            }
            .navigationTitle("All Users")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        MyFriends()
                    } label: {
                        Text("Saved users")
                    }
                }
            }
        }
    }
}

// show all saved user in database
struct MyFriends: View {
    var body: some View {
        
        Text("?")
    }
}

struct UserDetail: View {
    let user: User
    let users: [User]
    var body: some View {
        VStack {
            Text(user.name)
            Text(dateFormat(user.registered))
            Text("is friend with")
            List {
                ForEach(user.friends) { friend in
                    NavigationLink {
                        if let u = findUserWithId(id: friend.id) {
                            UserDetail(user: u, users: users)
                        } else {
                            Text("Invalid user :(")
                        }
                    } label: {
                        Text(friend.name)
                    }
                }
            }
        }
    }
    
    func dateFormat(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM dd YYYY"
        return formatter.string(from: date)
    }
    
    func findUserWithId(id: String) -> User? {
        users.first { $0.id == id }
    }
}

class DataModel: ObservableObject {
    // when this class get initialized, it will fetch json using url and store in memory
    // in a array of Users
    // The @Published is needed here because it need time to get json from the internet
    // so after the users get updated, it need @Published for UI to detect change and update
    @Published var users: [User] = []
    
    let container = NSPersistentContainer(name: "Bookworm")
    
    // everytime the app load, it will try to fetch data to check if the data has changed,
    // however if load fail we can still use core data as backup somehow
    init() {
        // load data from core data if there is any
        container.loadPersistentStores { desc, error in
            if let error = error {
                print("Core data error: \(error.localizedDescription)")
                return
            }
        }
        self.container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
    
        // force unwrap URL?, hardcode link should not fail
        let url = URL(string: "https://www.hackingwithswift.com/samples/friendface.json")!
        
        // use the url to make a request to get back some json
        let session = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error { // error in callback is not nil
                print("client error, \(error.localizedDescription)")
                return
            }
            
            // check if request sucessful
            guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode) else {
                        print("server error")
                        return
            }
            
            // check if data is json and save to users array
            if let mimiType = httpResponse.mimeType, mimiType == "application/json", let data = data {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let context = self.container.viewContext
                
                // this closure is not in main thread, but it update users which update UI so it has to
                // modify users in the main queue
                DispatchQueue.main.async {
                    do {
                        self.users = try decoder.decode([User].self, from: data)
                        // fetch and decode new data successful, so save to core data
                        for user in self.users {
                            let saveUser = CacheUser(context: context)
                            saveUser.id = user.id
                            saveUser.isActive = user.isActive
                            saveUser.name = user.name
                            saveUser.age = Int16(user.age)
                            saveUser.company = user.company
                            saveUser.email = user.email
                            saveUser.address = user.address
                            saveUser.about = user.about
                            saveUser.registered = user.registered
                            saveUser.tags = user.tags.joined(separator: ",")
                            for friend in user.friends {
                                let saveFriend = CacheFriend(context: context)
                                saveFriend.id = friend.id
                                saveFriend.name = friend.name
                                saveFriend.user = saveUser // make one to many relationship
                            }
                        }
                        try? context.save()
                    } catch {
                        print("fetch json failed")
                    }
                    
                    // if until this point, the users [User] is empty, that mean the fetch json has failed
                    // so use core data instead
                    // TODO
                    let fetchRequest: NSFetchRequest<CacheUser> = NSFetchRequest(entityName: "CacheUser")
                    
                    
                    if let fetchResult = try? context.fetch(fetchRequest) {
                        for cacheUser in fetchResult {
                            let id = cacheUser.id ?? "unknown id"
                            let isActive = cacheUser.isActive ?? false
                            let name = cacheUser.name ?? "unknown name"
                            
                            let age = Int(cacheUser.age) ?? 0
                            let company = cacheUser.company ?? "unknown company"
                            let email = cacheUser.email ?? "unknown company"
                            let address = cacheUser.address ?? "unknown address"
                            let about = cacheUser.about ?? "unknown about"
                            let registered = cacheUser.registered ?? Date.now
                            let tags = cacheUser.tags?.split(separator: ",").map {String($0)} ?? []
                            print(type(of: tags))
                            var friends = [User.Friend]()
                            //cacheUser.friends is NSSet? -> [User.Friend]
                            let set = cacheUser.friends as? Set<CacheFriend> ?? []
                            for cacheFriend in set {
                                let friendId = cacheFriend.id ?? "unknown friend id"
                                let friendName = cacheFriend.name ?? "unknown friend name"
                                friends.append(User.Friend(id: friendId, name: friendName))
                            }
                            self.users.append(User(id: id, isActive: isActive, name: name, age: age, company: company, email: email, address: address, about: about, registered: registered, tags: tags, friends: friends))
                        }
                        print("use core data instead")
                    }
                }
            }
        }
        session.resume()
    }
}

struct User: Codable, Identifiable {
    var id: String
    var isActive: Bool
    var name: String
    var age: Int
    var company: String
    var email: String
    var address: String
    var about: String
    var registered: Date // TODO change to date later
    var tags: [String]
    var friends: [Friend]
    
    struct Friend: Codable, Identifiable {
        var id: String
        var name: String
    }
}
*/

// Bookworm
/*
struct AddBookView: View {
    @State var showSheet = false
    
    @State var bookName = ""
    @State var authorName = ""
    @State var genre = genres[0]
    @State var review = ""
    @State var rating = 0
    
    static let genres = ["Fantasy", "Horror", "Kids", "Mystery", "Poetry", "Romance", "Thriller"]
    
    @Environment(\.managedObjectContext) var cont
    
    // how to use context to fetch a list of Book?
    @FetchRequest(sortDescriptors: [
        SortDescriptor(\.title),
        SortDescriptor(\.author)
    ]) var books: FetchedResults<Book>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(books) { book in
                    NavigationLink {
                        BookDetail(book: book)
                    } label: {
                        HStack {
                            Text("\(book.rating)")
                                .font(.largeTitle)
                            VStack(alignment: .leading) {
                                Text(book.title ?? "Unknown title")
                                    .font(.headline)
                                Text(book.author ?? "Unknown author")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteBook)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSheet = true
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showSheet) {
                NavigationView {
                    Form {
                        Section {
                            TextField("Name of book", text: $bookName)
                            TextField("Author name", text: $authorName)
                            Picker("Genre", selection: $genre) {
                                ForEach(AddBookView.genres, id:\.self) { g in
                                    Text(g)
                                }
                            }
                        }
                        Section {
                            TextEditor(text: $review)
                            BookRating(rating: $rating)
                        }
                        
                        Section {
                            Button("Add book") {
                                // use context to add a book to data
                                let book = Book(context: cont)
                                book.id = UUID()
                                book.title = bookName
                                book.author = authorName
                                book.genre = genre
                                book.review = review
                                book.rating = Int16(rating)
                                book.date = Date.now
                                
                                try? cont.save()
                                showSheet = false
                            }
                        }
                        
                    }
                    .navigationTitle("Add Book")
                }
            }
            .navigationTitle("Bookworm")
        }
    }
    
    func deleteBook(at offsets: IndexSet) {
        for offset in offsets {
            let book = books[offset]
            cont.delete(book)
        }
        try? cont.save()
    }
}

struct BookRating: View {
    @Binding var rating: Int
    var lable = ""
    var maximumRating = 5
    var offImage: Image?
    var onImage = Image(systemName: "star.fill")
    var offColor = Color.gray
    var onColor = Color.yellow
    
    var body: some View {
        HStack {
            if lable.isEmpty == false {
                Text(lable)
            }
            ForEach(1..<maximumRating+1, id: \.self) { number in
                image(for: number)
                    .foregroundColor(number > rating ? offColor : onColor)
                    .onTapGesture {
                        rating = number
                    }
            }
        }
    }
    
    func image(for number: Int) -> Image {
        if number > rating {
            return offImage ?? onImage
        } else {
            return onImage
        }
    }
}

struct BookDetail: View {
    let book: Book
    var body: some View {
        ScrollView {
            Image(book.genre ?? "Fantasy")
                .resizable()
                .scaledToFit()
            Text(book.author ?? "Unknown author")
            BookRating(rating: .constant(Int(book.rating)))
        }
        .navigationTitle(book.title ?? "Unknown title")
    }
}

class BookModel: ObservableObject {
    let container = NSPersistentContainer(name: "Bookworm")
    
    init() {
        container.loadPersistentStores { desc, error in
            if let error = error {
                print("Core data error: \(error.localizedDescription)")
            }
        }
    }
}

// Cupcake corner
struct CupcakeView: View {
    @StateObject var mainOrder = OrderModel()
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Select your cake type", selection: $mainOrder.order.type) {
                        ForEach(Order.types, id: \.self) { cupcakeType in
                            Text(cupcakeType)
                        }
                    }
                    Stepper("Number of cakes \(mainOrder.order.number)", value: $mainOrder.order.number, in: 3...20)
                }
                
                Section {
                    Toggle("Any special request?", isOn: $mainOrder.order.specialRequest.animation())
                    if (mainOrder.order.specialRequest) {
                        Toggle("Add extra frosting", isOn: $mainOrder.order.frosting)
                    }
                }
                
                Section {
                    NavigationLink {
                        AddressView(mainOrder: mainOrder)
                        //Test(mainOrder: mainOrder)
                    } label: {
                        Text("Delivery detail")
                    }
                }
            }
            .navigationTitle("Cupcake Corner")
        }
    }
}

struct AddressView: View {
    @ObservedObject var mainOrder: OrderModel
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $mainOrder.order.name)
                TextField("Street adress", text: $mainOrder.order.street)
                TextField("City", text: $mainOrder.order.city)
                TextField("Zip", text: $mainOrder.order.zip)
            }
            
            Section {
                NavigationLink {
                    Checkout(mainOrder: mainOrder)
                } label: {
                    Text("Check out")
                }
            }
            .navigationTitle("Delivery details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct Checkout: View {
    @State var confirmationMessage = ""
    @State var showConfimation = false
    
    @ObservedObject var mainOrder: OrderModel
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: "https://hws.dev/img/cupcakes@3x.jpg"), scale: 3) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
            }
            
            Button("Place order") {
                Task {
                    await placeOrder()
                }
            }
        }
        .alert("Thank you", isPresented: $showConfimation) {
            Button("Ok") {}
        } message: {
            Text(confirmationMessage)
        }
    }
    
    func placeOrder() async {
        // convert data to json
        guard let encoded = try? JSONEncoder().encode(mainOrder) else {
            print("failed to encode order")
            return
        }
        
        // create the url to send request
        let url = URL(string: "https://reqres.in/api/cupcakes")!
        
        // create the http request
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        // send the request
        do {
            let (data, _) = try await URLSession.shared.upload(for: request, from: encoded)
            let decodedOrder = try JSONDecoder().decode(OrderModel.self, from: data)
            confirmationMessage = "Your order for \(decodedOrder.order.number)x\(decodedOrder.order.type) with total of $\(decodedOrder.order.total)"
            showConfimation = true
        } catch {
            print("check out failed")
        }
    }
}

class OrderModel: ObservableObject, Codable {
    enum CodingKeys: CodingKey {
        case order
    }
    
    @Published var order = Order()
    
    init() {}
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(order, forKey: .order)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decode(Order.self, forKey: .order)
    }
}

struct Order: Codable {
    static let types : [String] = ["chocolate", "rainbow", "vanilla"]
    var type: String = types[0]
    var number: Int = 2
    var specialRequest: Bool = false {
        didSet {
            frosting = false
        }
    }
    var frosting: Bool = false
    
    var total: Int {
        var cost = 2 * number
        if frosting { cost += 1 }
        return cost
    }
    
    var name: String = ""
    var street: String = ""
    var city: String = ""
    var zip: String = ""
}



// Habit tracking Challenge
struct HabitTracking: View {
    @ObservedObject var habitApp: HabitApp
    @State var showSheet = false
    @State var habitName = ""
    @State var habitDescription = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(habitApp.habits) { habit in
                    NavigationLink {
                        HabitDetail(habit: habit, habits: habitApp)
                    } label: {
                        Text(habit.name)
                    }
                }
                .onDelete(perform: removeHabit)
            }
            .toolbar {
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showSheet) {
                NavigationStack {
                    Form {
                        TextField("Enter habit name", text: $habitName)
                        TextField("Enter habit description", text: $habitDescription)
                    }
                    .toolbar {
                        Button {
                            habitApp.habits.append(Habit(name: habitName, description: habitDescription))
                            showSheet = false
                            habitName = ""
                            habitDescription = ""
                        } label: {
                            Text("Save")
                        }
                    }
                    .navigationTitle("Add habit")
                }
            }
            .navigationTitle("Habit Tracker")
        }
    }
    
    func removeHabit(_ of: IndexSet) {
        habitApp.habits.remove(atOffsets: of)
    }
    
    struct HabitDetail: View {
        @Environment(\.dismiss) var dismiss
        let habit: Habit
        @ObservedObject var habits: HabitApp
        var habitIndex: Int
        let habitDetailName: String
        let habitDetailDescription: String
        
        @State var habitName: String = ""
        @State var habitDescription: String = ""
        
        init(habit: Habit, habits: HabitApp) {
            self.habit = habit
            self.habits = habits
            habitIndex = habits.habits.firstIndex(where: {habit.id == $0.id})!
            habitDetailName = habits.habits[habitIndex].name
            habitDetailDescription = habits.habits[habitIndex].description
        }
        
        var body: some View {
            Form {
                TextField(habitDetailName, text: $habitName)
                TextField(habitDetailDescription, text: $habitDescription)
            }
            .toolbar {
                Button {
                    habits.habits[habitIndex].name = habitName
                    habits.habits[habitIndex].description = habitDescription
                    // self dismiss view
                    dismiss()
                } label: {
                    Text("Save")
                }
            }
        }
    }
    
}

struct Habit: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var completeTimes = 0
}

class HabitApp: ObservableObject {
    @Published var habits = [Habit]() {
        didSet {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(habits) {
                UserDefaults.standard.set(data, forKey: "habits")
            }
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "habits") {
            let decoder = JSONDecoder()
            if let result = try? decoder.decode([Habit].self, from: data) {
                habits = result
            }
        }
    }
    
    func addHabit(_ h: Habit) {
        habits.append(h)
    }
    
    func loadHabit() {
        
    }
}

struct Moonshot: View {
    static let astronauts:[String:Astronaut] = Bundle.main.decode("astronauts.json")
    static let missions:[Mission] = Bundle.main.decode("missions.json")
    let columns = [GridItem(.adaptive(minimum: 150))]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(Moonshot.missions) { mission in
                        NavigationLink {
                            MissionDetail(mission: mission)
                        } label: {
                            MissionView(id: mission.id, launchDate: mission.formattedLaunchDate)
                        }
                    }
                }
                .padding([.horizontal])
            }
            .navigationTitle("Moon Shot")
            .background(.darkBackground)
            .preferredColorScheme(.dark)
        }
    }
    
    struct MissionDetail: View {
        var image: String {
            "apollo\(mission.id)"
        }
        let mission:Mission
        
        var body: some View {
            GeometryReader { geo in
                ScrollView {
                    VStack {
                        Image(image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geo.size.width * 0.6)
                        VStack(alignment: .leading) {
                            Text("Mission Highlights")
                                .font(.title.bold())
                                .padding(.bottom, 5)
                            Text(mission.description)
                            Text("Crew")
                                .font(.headline)
                            ScrollView(.horizontal,showsIndicators: false) {
                                HStack {
                                    ForEach(mission.crew, id:\.role) { crew in
                                        NavigationLink {
                                            AstronautView(astronauts[crew.name]!)
                                        } label: {
                                            HStack {
                                                Image(crew.name)
                                                    .resizable()
                                                    .frame(width: 104, height: 72)
                                                    .clipShape(Capsule())
                                                    .overlay {
                                                        Capsule()
                                                            .strokeBorder(.white, lineWidth: 1)
                                                    }
                                                VStack(alignment: .leading) {
                                                    Text(crew.name.capitalized)
                                                        .foregroundColor(.white)
                                                        .font(.headline)
                                                    Text(crew.role)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
                .navigationTitle(mission.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .background(.darkBackground)
            }
        }
    }
    
    struct AstronautView: View {
        let astronaut: Astronaut
        init(_ astronaut: Astronaut) {
            self.astronaut = astronaut
        }
        var body: some View {
            ScrollView {
                VStack {
                    Image("\(astronaut.id)")
                        .resizable()
                        .scaledToFit()
                        .padding(.bottom)
                    Text(astronaut.description)
                        .padding(.horizontal)
                }
                .navigationTitle(astronaut.name)
            }
            .background(.darkBackground)
        }
    }
    
    struct MissionView: View {
        let id: Int
        var image: String {
            "apollo\(id)"
        }
        var name: String {
            "Apollo \(id)"
        }
        let launchDate: String
        
        var body: some View {
            VStack {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding()
                VStack {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(launchDate)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(.lightBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.lightBackground)
            )
        }
    }
}

extension Bundle {
    func decode<T:Decodable>(_ fileName:String) -> T {
        if let url = self.url(forResource: fileName, withExtension: nil) {
            if let data = try? Data(contentsOf: url) {
                let formatter = DateFormatter()
                formatter.dateFormat = "y-MM-dd"
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(formatter)
                if let result = try? decoder.decode(T.self, from: data) {
                    return result
                }
            }
        }
        fatalError("Failed load file \(fileName)")
    }
}

extension ShapeStyle where Self == Color {
    static var darkBackground: Color {
        Color(red: 0.1, green: 0.1, blue: 0.2)
    }
    
    static var lightBackground: Color {
        Color(red: 0.2, green: 0.2, blue: 0.3)
    }
}

struct Astronaut:Decodable, Identifiable {
    let id: String
    let name: String
    let description: String
}

struct Mission:Decodable, Identifiable {
    let id: Int
    let launchDate: Date?
    let crew: [CrewMember]
    let description: String
    
    var formattedLaunchDate: String {
        launchDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
    }
    
    var displayName: String {
        "Apollo \(id)"
    }
    
    struct CrewMember:Decodable {
        let name: String
        let role: String
    }
}

// END Moonshot

// iExpense

struct ExpenseItem: Identifiable, Codable {
    var id = UUID()
    let name: String
    let category: String
    let cost: Double
}

class Expenses: ObservableObject {
    @Published var data: [ExpenseItem] = [] {
        didSet {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(data) {
                UserDefaults.standard.set(encoded, forKey: "Items")
            }
        }
    }
    
    init() {
        if let savedItems = UserDefaults.standard.data(forKey: "Items") {
            if let decodedItems = try? JSONDecoder().decode([ExpenseItem].self, from: savedItems) {
                data = decodedItems
                return
            }
        }
        data = []
    }
}

struct iExpense: View {
    @StateObject var expenses = Expenses() // hmm, probably want to creat this in ContentView or App and pass to this
    
    @State var showSheet = false
    @State var expenseName: String = ""
    @State var expenseCategory: String = "Personal"
    @State var cost: Double = 0.0
    let allCategories = ["Personal", "Business"]
    
    var body: some View {
        NavigationStack {
            Form {
                ForEach(expenses.data) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.category)
                        }
                        Spacer()
                        Text(item.cost.formatted(.currency(code: "USD")))
                    }
                }
                .onDelete(perform: removeItem)
            }
            .toolbar {
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showSheet) {
                NavigationStack {
                    Form {
                        TextField("Expense name", text: $expenseName)
                        Picker("Type", selection: $expenseCategory) {
                            ForEach(allCategories, id: \.self) {
                                Text($0)
                            }
                        }
                        TextField("\(cost)", value: $cost, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                    }
                    .toolbar {
                        Button {
                            expenses.data.append(ExpenseItem(name:expenseName, category: expenseCategory, cost: cost))
                            showSheet = false
                        } label: {
                            Text("Save")
                        }
                    }
                    .navigationTitle("Add new expense")
                }
            }
            .navigationTitle("iExpense")
        }
    }
    
    func removeItem(perform at: IndexSet) {
        expenses.data.remove(atOffsets: at)
    }
}
// End iExpense

struct AnimationTest: View {
    @State var animationAmount = 0.0
    @State var second: Bool = false
    @State var second2: Bool = false
    @State var dragAmount = CGSize.zero
    @State var dragAmount2 = CGSize.zero
    let str = Array("Hello, SwiftUI")
    
    var body: some View {
        VStack {
            Button("First") {
                withAnimation(.linear(duration: 1)) {
                    animationAmount += 360
                }
            }
            .padding(50)
            .background(.red)
            .foregroundColor(.white)
            .clipShape(Circle())
            .rotation3DEffect(.degrees(animationAmount), axis: (x: 1, y: 1, z: 0))
            
            Button("Second") {
                second.toggle()
            }
            .frame(width: 120, height: 120)
            .background(second ? .red : .blue)
            .foregroundColor(.white)
            .animation(.default, value: second)
            .clipShape(RoundedRectangle(cornerRadius: second ? 60 : 0))
            .animation(.interpolatingSpring(stiffness: 10, damping: 1), value: second)
            
            LinearGradient(colors: [.red,.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 200, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .offset(dragAmount)
                .gesture(
                    DragGesture()
                        .onChanged { dragAmount = $0.translation }
                        .onEnded { _ in
                            withAnimation {
                                dragAmount = .zero
                            }
                        }
                )
            
            HStack(spacing:0){
                ForEach(0..<14) { num in
                    Text(String(str[num]))
                        .padding(5)
                        .font(.title)
                        .background(second2 ? .blue : .red)
                        .offset(dragAmount2)
                        .animation(.default.delay(Double(num)/20), value: dragAmount2)
                }
                .gesture(
                    DragGesture()
                        .onChanged {dragAmount2 = $0.translation}
                        .onEnded{_ in
                            dragAmount2 = .zero
                            second2.toggle()
                        }
                )
            }
        }
    }
}

struct Scramble: View {
    @State var originalWord: String = originalWords.randomElement()!
    @State var currentWord: String = ""
    static let originalWords = loadWords()
    @State var validWords:[String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter your word", text: $currentWord)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            addWord()
                        }
                }
                List(validWords, id:\.self) { word in
                    HStack {
                        Image(systemName: "\(word.count).circle")
                        Text(word)
                    }
                }
            }
            .navigationTitle(Text(originalWord))
        }
    }
    
    static func loadWords() -> [String] {
        if let url = Bundle.main.url(forResource: "start", withExtension: "txt") {
            if let data = try? String(contentsOf: url) {
                return data.components(separatedBy: "\n")
            }
        }
        fatalError("Can not load start.txt")
    }
    
    func addWord() {
        let answer = currentWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard answer.count > 0 else { return }
        validWords.insert(answer, at: 0)
        currentWord = ""
    }
}

struct BetterRest: View {
    @State var wakeUp: Date = .now
    @State var sleep: Double = 4.0
    @State var coffeeAmount: Int = 0
    var body: some View {
        NavigationStack {
            Form {
                VStack(alignment: .leading) {
                    Text("When do you want to wake up?")
                    DatePicker("Please enter a time",selection: $wakeUp, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                VStack {
                    Text("Desired amount of sleep")
                    Stepper("\(sleep.formatted()) hours", value: $sleep, in: 4...10, step: 0.5)
                }
                VStack {
                    Text("Daily coffee intake")
                    Stepper("\(coffeeAmount.formatted()) cups", value: $coffeeAmount)
                }
            }
            .frame(maxHeight:300)
            .scrollContentBackground(.hidden)
            .navigationTitle("Better Rest")
            .listRowInsets(EdgeInsets())
            HStack(alignment: .center) {
                Button("Calculated") {
                    print("hello")
                }
            }
        }
    }
}

struct WeTip: View {
    @State var total: Double = 0.0
    @State var numberOfPeople: Int = 2
    @State var tipPercentage: Int = 20
    let tips: [Int] = [5,10,15,20,25]
    
    var result:Double {
        let PeopleCount = Double(numberOfPeople)
        let tipPercentage = Double(tipPercentage)
        let tipValue = total / 100 * tipPercentage
        let grandTotal = total + tipValue
        let amountPerperson = grandTotal / PeopleCount
        return amountPerperson
    }
    
    var body: some View {
        NavigationStack{
            VStack {
                Form {
                    TextField("Enter total bill", value: $total, format: .currency(code: "USD"))
                    Picker("number of people", selection: $numberOfPeople) {
                        ForEach(2...100, id: \.self) { n in
                            Text(String(n))
                        }
                    }
                    
                    Section("How much do you want to tip?") {
                        Picker("?", selection: $tipPercentage) {
                            ForEach(tips, id:\.self) { n in
                                Text(n, format: .percent)
                            }
                        }.pickerStyle(.segmented)
                    }
                    
                    Section("Amount per person") {
                        Text(result, format: .currency(code: "USD"))
                    }
                }
            }
            
            .navigationTitle("We Split")
        }
    }
}

struct One2Three: View {
    static var options = [1,2,3]
    @State var computerChoice = options.shuffled()[0]
    @State var userChoice: Int?
    @State var userScore: Int = 0
    
    @State var popUp:Bool = false
    
    // scissor = 1
    // hammer = 2
    // paper = 3
    
    var body: some View {
        VStack {
            Text("Pick a result")
            Group {
                Button("✌️") {
                    if computerChoice == 2 {
                        userScore -= 1
                    }
                    if computerChoice == 3 {
                        userScore += 1
                    }
                    popUp = true
                }
                Button("🫱") {
                    if computerChoice == 1 {
                        userScore -= 1
                    }
                    if computerChoice == 2 {
                        userScore += 1
                    }
                    popUp = true
                }
                Button("👊") {
                    if computerChoice == 3 {
                        userScore -= 1
                    }
                    if computerChoice == 1 {
                        userScore += 1
                    }
                    popUp = true
                }
            }
            .font(.system(size: 100))
            .border(.blue, width: 5)
            .cornerRadius(5)
            .padding(20)
            Text(userScore, format: .number)
        }
        .alert("Result", isPresented: $popUp) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text("Your score is \(userScore)")
        }
    }
}

// GUESS THE FLAG
struct GuessTheFlag: View {
    static let countries = ["Estonia", "France", "Germany", "Ireland", "Italy", "Monaco", "Nigeria", "Poland", "Spain", "UK", "US", "Ukraine"]
    @State var chosenCountries: [String] = foo()
    @State var currentCountry: Int = foo1()
    @State var score: Int = 0
    @State var wrong: Bool = false
    @State var lastScore: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack{
                Color(red: 0.373, green: 0.16, blue: 0.9)
                    .ignoresSafeArea()
                Circle()
                    .fill(Color(red: 0.99, green: 0.3, blue: 0.8))
                    .position(CGPoint(x: geometry.size.width/2,y: -50))
                VStack {
                    Spacer()
                    Text("\(chosenCountries[currentCountry])")
                    Spacer()
                    Spacer()
                    VStack(spacing: 0) {
                        ForEach(chosenCountries, id: \.self) { country in
                            flagButton(flag: country, currentCountry: chosenCountries[currentCountry], score: $score, chosenCountry: $chosenCountries, cuurent: $currentCountry, wrong: $wrong, last: $lastScore)
                        }
                    }
                        .background(.cyan)
                        .cornerRadius(20)
                    Spacer()
                    Text("Score: \(score)")
                    Spacer()
                }
                .font(.system(size: 30))
                .foregroundColor(.white)
                .fontWeight(.heavy)
                .alert("Wrong Answer", isPresented: $wrong) {
                    Button("Ok", role: .cancel) {}
                    Button("Whatever", role: .destructive) {}
                } message: {
                    Text("Max score is \(lastScore)")
                }
            }
        }
    }
    
    static func foo() -> [String] {
        var m:[Int:Bool] = [:]
        var temp:[String] = []
        while(temp.count < 3) {
            let i = Int.random(in: 0..<GuessTheFlag.countries.count)
            if let _ = m[i] {
                continue
            }
            temp.append(GuessTheFlag.countries[i])
            m[i] = true
        }
        return temp
    }
    
    static func foo1() -> Int {
        return Int.random(in: 0..<3)
    }
    
    struct flagButton: View {
        let flag: String
        var currentCountry: String
        @Binding var score: Int
        @Binding var chosenCountry: [String]
        @Binding var cuurent: Int
        @Binding var wrong: Bool
        @Binding var last: Int
        
        var body: some View {
            Button {
                if flag == currentCountry {
                    score += 1
                    last = score
                } else {
                    score = 0
                    wrong = true
                }
                chosenCountry = GuessTheFlag.foo()
                cuurent = GuessTheFlag.foo1()
            } label: {
                Image(flag)
            }
            .cornerRadius(10)
            .padding(10)
        }
    }
}
*/
 

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            //.preferredColorScheme(.dark)
    }
}
